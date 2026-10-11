#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
NAMESPACE=""
API_KEY="${QDRANT_API_KEY:-}"
COLLECTION_NAME=""
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
DUMP_FILE=""
MODE=""
TARGET=""
QDRANT_PORT="6333"
NAMESPACE_ARG=""
POD_NAME=""
SERVICE_NAME=""
QDRANT_URL=""
LOCAL_PORT=""
PF_PID=""
PF_LOG=""
LOCAL_TMP_PATHS=()

# Script helper
TEXT_HELPER="
This script aims to perform a snapshot on a kubernetes qdrant pod and copy locally the snapshot files, or the opposite, restore local snapshot files to a qdrant pod.

It forwards a random free local port to the pod and drives the Qdrant snapshot API with the local
curl, one snapshot per collection.

Available flags:
  -a    API key for Qdrant authentication (optional).
        Prefer the QDRANT_API_KEY environment variable: a -a value shows in the local process list.
  -c    Name of the pod's container (unused, kept for compatibility).
  -r    Specific collection name to backup/restore (if not specified, all collections will be processed).
        When restoring a single file, the collection to restore it into.
  -f    Local snapshot file or directory to restore (only needed with restore mode).
  -m    Mode to run. Available modes are:
          dump_forward      - Create snapshots locally using port forward + API.
          restore_forward   - Restore local snapshots using port forward + API.
          list              - List available collections.
        The former 'dump' and 'restore' modes are no longer available: the Qdrant
        '--storage-snapshot' flag they relied on only restores a snapshot when a server
        starts, it cannot snapshot or restore a running pod.
  -n    Kubernetes namespace target where the qdrant pod is running.
        Default: the namespace of the current kubectl context.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Qdrant port (default: '$QDRANT_PORT').
  -t    Target name of the pod or service to run the snapshot on.
  -h    Print script help.

Example:
  QDRANT_API_KEY='my-api-key' ./backup-kube-qdrant.sh \\
    -m 'dump_forward' \\
    -t 'my-qdrant-pod' \\
    -r 'my-collection'

  QDRANT_API_KEY='my-api-key' ./backup-kube-qdrant.sh \\
    -m 'restore_forward' \\
    -t 'my-qdrant-pod' \\
    -f './backups/20240101T1200-qdrant'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

error () {
  printf "\n${COLOR_RED}Error.${COLOR_OFF} %s\n" "$1" >&2
}

cleanup () {
  local STATUS=$?
  if [ -n "$PF_PID" ]; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  if [ -n "$PF_LOG" ]; then
    rm -f "$PF_LOG"
  fi
  if [ ${#LOCAL_TMP_PATHS[@]} -gt 0 ]; then
    rm -rf "${LOCAL_TMP_PATHS[@]}"
  fi
  exit "$STATUS"
}

getPodFromService() {
  local SVC_NAME="$1"
  SELECTOR=$(kubectl $NAMESPACE_ARG get svc "$SVC_NAME" -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
  if [[ -z "$SELECTOR" ]]; then
    echo "No selector found for service $SVC_NAME" >&2
    exit 1
  fi
  POD_NAME=$(kubectl $NAMESPACE_ARG get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}')
  if [[ -z "$POD_NAME" ]]; then
    echo "No pods found for selector '$SELECTOR' in namespace '$NAMESPACE'." >&2
    exit 1
  else
    echo "$POD_NAME"
  fi
}

# Forwards a random free local port to the pod's Qdrant port, waits for the tunnel to listen and
# sets QDRANT_URL, so requests never reach a Qdrant instance already running on this machine.
startPortForward () {
  local TRIES=0
  PF_LOG="$(mktemp)"
  kubectl ${NAMESPACE_ARG} port-forward --address 127.0.0.1 "pod/${POD_NAME}" ":${QDRANT_PORT}" > "$PF_LOG" 2>&1 &
  PF_PID=$!
  while true; do
    LOCAL_PORT="$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9][0-9]*\) .*/\1/p' "$PF_LOG" | head -n 1)"
    [ -n "$LOCAL_PORT" ] && break
    if ! kill -0 "$PF_PID" 2>/dev/null || [ "$TRIES" -ge 30 ]; then
      cat "$PF_LOG" >&2
      error "Port forward to pod '${POD_NAME}' (port ${QDRANT_PORT}) did not start."
      exit 1
    fi
    TRIES=$((TRIES + 1))
    sleep 1
  done
  QDRANT_URL="http://127.0.0.1:${LOCAL_PORT}"
  printf "Forwarding 127.0.0.1:%s to pod '%s' port %s.\n" "$LOCAL_PORT" "$POD_NAME" "$QDRANT_PORT"
}

# curl against the forwarded API, failing on HTTP errors. The api-key header is read from stdin
# (-H @-) so the key never shows in curl's argument list.
qcurl () {
  if [ -n "$API_KEY" ]; then
    printf 'api-key: %s\n' "$API_KEY" | curl -fsS -H @- "$@"
  else
    curl -fsS "$@"
  fi
}

urlEncode () {
  jq -rn --arg x "$1" '$x | @uri'
}

listCollections () {
  qcurl "${QDRANT_URL}/collections" | jq -r '.result.collections[].name'
}

# Qdrant names snapshots '<collection>-<peer id>-<YYYY-MM-DD-HH-MM-SS>.snapshot' and dump_forward
# saves them as '<collection>-<snapshot name>', so the collection is what precedes that suffix
# (once, if dump_forward doubled it), not the text before the first dash.
collectionFromFile () {
  local NAME="${1%.snapshot}"
  local SUFFIX_RE='^(.+)-[0-9]+-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$'
  local HALF
  if [[ "$NAME" =~ $SUFFIX_RE ]]; then
    NAME="${BASH_REMATCH[1]}"
    HALF=$(( (${#NAME} - 1) / 2 ))
    if [ $(( ${#NAME} % 2 )) -eq 1 ] && [ "${NAME:HALF:1}" = "-" ] && [ "${NAME:0:HALF}" = "${NAME:HALF+1}" ]; then
      NAME="${NAME:0:HALF}"
    fi
  fi
  printf '%s\n' "$NAME"
}

uploadSnapshot () {
  local SNAPSHOT_FILE="$1"
  local COLLECTION="$2"
  printf "\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Restoring collection: %s (file: %s)\n" "$COLLECTION" "$SNAPSHOT_FILE"
  # priority=snapshot makes the uploaded data win over what the collection currently holds
  qcurl -X POST "${QDRANT_URL}/collections/$(urlEncode "$COLLECTION")/snapshots/upload?priority=snapshot" \
    -F "snapshot=@${SNAPSHOT_FILE}"
  echo
}

# Parse options
while getopts ha:c:r:f:m:n:o:p:t: flag; do
  case "${flag}" in
    a)
      API_KEY=${OPTARG};;
    c)
      ;;
    r)
      COLLECTION_NAME=${OPTARG};;
    f)
      DUMP_FILE=${OPTARG};;
    m)
      MODE=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    o)
      EXPORT_DIR=${OPTARG};;
    p)
      QDRANT_PORT=${OPTARG};;
    t)
      TARGET=${OPTARG};;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Init
if [ -z "$NAMESPACE" ]; then
  NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null || true)"
fi
[[ -n "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"

# Options validation
if [ -z "$MODE" ]; then
  error "Argument missing: mode (flag -m)."
  exit 1
elif [ "$MODE" = "dump" ] || [ "$MODE" = "restore" ]; then
  error "Mode '$MODE' is no longer available: Qdrant's '--storage-snapshot' flag only restores a snapshot at server start, it cannot snapshot or restore a running pod. Use '${MODE}_forward' instead."
  exit 1
elif [ "$MODE" != "dump_forward" ] && [ "$MODE" != "restore_forward" ] && [ "$MODE" != "list" ]; then
  error "Unknown mode '$MODE' (flag -m)."
  exit 1
elif [ -z "$TARGET" ]; then
  error "Argument missing: target pod or service (flag -t)."
  exit 1
elif [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  error "Argument missing: dump file or directory (flag -f)."
  exit 1
elif [ "$MODE" = "restore_forward" ] && [ ! -e "$DUMP_FILE" ]; then
  error "Dump file or directory '$DUMP_FILE' not found (flag -f)."
  exit 1
fi

if [[ "$TARGET" == svc/* || "$TARGET" == service/* ]]; then
  SERVICE_NAME="${TARGET#*/}"
  POD_NAME=$(getPodFromService "$SERVICE_NAME")
  if [[ -z "$POD_NAME" ]]; then
    echo "No pods found for service : $SERVICE_NAME" >&2
    exit 1
  fi
elif [[ "$TARGET" == pod/* ]]; then
  POD_NAME="${TARGET#*/}"
else
  POD_NAME="$TARGET"
fi

# Settings
printf "
Settings:
  > MODE: ${MODE}
  > EXPORT_DIR: ${EXPORT_DIR}
  > DUMP_FILE: ${DUMP_FILE}
  > COLLECTION_NAME: ${COLLECTION_NAME:-"all"}
  > API_KEY: $([ -n "$API_KEY" ] && echo 'set' || echo 'not set')
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > QDRANT_PORT: ${QDRANT_PORT}
"

# List collections
if [ "$MODE" = "list" ]; then
  printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Listing collections.\n\n"

  startPortForward
  if ! COLLECTIONS=$(listCollections); then
    error "Unable to list collections through the port forward."
    exit 1
  fi

  if [ -n "$COLLECTIONS" ]; then
    printf "${COLOR_GREEN}Available collections:${COLOR_OFF}\n"
    echo "$COLLECTIONS" | while read -r collection; do
      printf "  - %s\n" "$collection"
    done
  else
    printf "${COLOR_YELLOW}No collections found.${COLOR_OFF}\n"
  fi

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  BACKUP_DIR="${EXPORT_DIR}/${DATE_TIME}-qdrant"
  mkdir -p "$BACKUP_DIR"

  printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Creating snapshots using port forward.\n\n"

  startPortForward

  # Get collections to backup
  if [ -n "$COLLECTION_NAME" ]; then
    COLLECTIONS="$COLLECTION_NAME"
  elif ! COLLECTIONS=$(listCollections); then
    error "Unable to list collections through the port forward."
    exit 1
  fi
  if [ -z "$COLLECTIONS" ]; then
    error "No collections found."
    exit 1
  fi

  # Create and download snapshots for each collection
  FAILED=()
  while IFS= read -r collection; do
    [ -n "$collection" ] || continue
    printf "\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Processing collection: %s\n" "$collection"
    COLLECTION_PATH="${QDRANT_URL}/collections/$(urlEncode "$collection")/snapshots"

    # Create snapshot
    SNAPSHOT_NAME=""
    if SNAPSHOT_RESULT=$(qcurl -X POST "$COLLECTION_PATH"); then
      SNAPSHOT_NAME=$(printf '%s' "$SNAPSHOT_RESULT" | jq -r '.result.name // empty' 2>/dev/null || true)
    fi
    if [ -z "$SNAPSHOT_NAME" ]; then
      printf "${COLOR_RED}Error creating snapshot for collection: %s${COLOR_OFF}\n" "$collection" >&2
      FAILED+=("$collection")
      continue
    fi

    # Download snapshot, under a temporary name until the download is complete
    LOCAL_SNAPSHOT="${BACKUP_DIR}/${collection}-${SNAPSHOT_NAME}"
    printf "${COLOR_GREEN}Downloading snapshot: %s${COLOR_OFF}\n" "$LOCAL_SNAPSHOT"
    LOCAL_TMP_PATHS=("${LOCAL_SNAPSHOT}.partial")
    if qcurl -o "${LOCAL_SNAPSHOT}.partial" "${COLLECTION_PATH}/$(urlEncode "$SNAPSHOT_NAME")"; then
      mv "${LOCAL_SNAPSHOT}.partial" "$LOCAL_SNAPSHOT"
    else
      rm -f "${LOCAL_SNAPSHOT}.partial"
      printf "${COLOR_RED}Error downloading snapshot for collection: %s${COLOR_OFF}\n" "$collection" >&2
      FAILED+=("$collection")
    fi
    LOCAL_TMP_PATHS=()
  done <<< "$COLLECTIONS"

  if [ ${#FAILED[@]} -gt 0 ]; then
    error "Backup incomplete, failed collections: ${FAILED[*]}."
    exit 1
  fi

elif [ "$MODE" = "restore_forward" ]; then
  printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Restoring snapshots using port forward.\n\n"

  startPortForward

  if [ -d "$DUMP_FILE" ]; then
    # Restore from directory, only the -r collection when given
    RESTORED=0
    for snapshot_file in "$DUMP_FILE"/*; do
      # Skip what is not a complete download
      [ -f "$snapshot_file" ] || continue
      [[ "$snapshot_file" == *.partial ]] && continue
      collection=$(collectionFromFile "$(basename "$snapshot_file")")
      if [ -n "$COLLECTION_NAME" ] && [ "$collection" != "$COLLECTION_NAME" ]; then
        continue
      fi
      uploadSnapshot "$snapshot_file" "$collection"
      RESTORED=$((RESTORED + 1))
    done
    if [ "$RESTORED" -eq 0 ]; then
      error "No snapshot to restore in '$DUMP_FILE'${COLLECTION_NAME:+ for collection '$COLLECTION_NAME'}."
      exit 1
    fi
  else
    # Restore single file
    collection="${COLLECTION_NAME:-$(collectionFromFile "$(basename "$DUMP_FILE")")}"
    uploadSnapshot "$DUMP_FILE" "$collection"
  fi
fi

printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Operation completed successfully.\n\n"

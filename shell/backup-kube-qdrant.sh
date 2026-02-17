#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
CONTAINER_NAME=""
API_KEY=""
COLLECTION_NAME=""
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
DUMP_PATH=""
DUMP_FILE=""
MODE=""
TARGET=""
QDRANT_PORT="6333"
NAMESPACE_ARG=""
CONTAINER_ARG=""
AUTH_HEADER=""
POD_NAME=""
SERVICE_NAME=""
HTTP_CLIENT=""
BASE_URL=""
PATHS=(
  /qdrant/storage
  /tmp
  /var/tmp
)

# Script helper
TEXT_HELPER="
This script aims to perform a snapshot on a kubernetes qdrant pod and copy locally the snapshot files, or the opposite, restore local snapshot files to a qdrant pod.

NOTE: Qdrant containers have a built-in CLI at /qdrant/qdrant for snapshots:
  - dump/restore (uses Qdrant CLI + kubectl cp)
  - dump_forward/restore_forward (uses port forwarding + API calls)

Available flags:
  -a    API key for Qdrant authentication (optional).
  -c    Name of the pod's container.
  -r    Specific collection name to backup/restore (if not specified, all collections will be processed).
  -f    Local snapshot file or directory to restore (only needed with restore mode).
  -m    Mode to run. Available modes are:
          dump              - Create snapshots using Qdrant CLI and copy them locally.
          dump_forward      - Create snapshots locally using port forward + API.
          restore           - Restore local snapshots using Qdrant CLI.
          restore_forward   - Restore local snapshots using port forward + API.
          list              - List available collections.
  -n    Kubernetes namespace target where the qdrant pod is running.
        Default: current namespace '$NAMESPACE'.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Qdrant port (default: '$QDRANT_PORT').
  -t    Target name of the pod or service to run the snapshot on.
  -h    Print script help.

Example:
  # CLI mode (like Vault - uses Qdrant CLI)
  ./backup-kube-qdrant.sh \\
    -m 'dump' \\
    -t 'my-qdrant-pod' \\
    -o './backups'

  ./backup-kube-qdrant.sh \\
    -m 'restore' \\
    -t 'my-qdrant-pod' \\
    -f './backups/20240101T1200-qdrant'

  # Port forwarding mode (uses local curl + API)
  ./backup-kube-qdrant.sh \\
    -m 'dump_forward' \\
    -t 'my-qdrant-pod' \\
    -r 'my-collection' \\
    -a 'my-api-key'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

isRW() {
  kubectl $NAMESPACE_ARG exec ${POD_NAME} -- sh -c "[ -w $1 ] && echo 'true' || echo 'false'"
}

hasHttpClient() {
  if kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- which curl >/dev/null 2>&1; then
    HTTP_CLIENT="curl"
    return 0
  elif kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- which wget >/dev/null 2>&1; then
    HTTP_CLIENT="wget"
    return 0
  else
    return 1
  fi
}

getPodFromService() {
  local SVC_NAME="$1"
  SELECTOR=$(kubectl $NAMESPACE_ARG get svc "$SVC_NAME" -o jsonpath='{.spec.selector}' | jq -r 'to_entries | map("\(.key)=\(.value)") | join(",")')
  if [[ -z "$SELECTOR" ]]; then
    echo "No selector found for service $SVC_NAME"
    exit 1
  fi
  POD_NAME=$(kubectl $NAMESPACE_ARG get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}')
  if [[ -z "$POD_NAME" ]]; then
    echo "No pods found for selector '$SELECTOR' in namespace '$NAMESPACE'."
    exit 1
  else
    echo "$POD_NAME"
  fi
}

getCollections() {
  local base_url="$1"
  local auth_header="$2"
  
  if [ "$HTTP_CLIENT" = "curl" ]; then
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- curl -s ${auth_header} "${base_url}/collections" | jq -r '.result.collections[].name' 2>/dev/null || echo ""
  else
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- wget -q -O- ${auth_header} "${base_url}/collections" | jq -r '.result.collections[].name' 2>/dev/null || echo ""
  fi
}

createSnapshot() {
  local base_url="$1"
  local collection="$2"
  local auth_header="$3"
  
  if [ "$HTTP_CLIENT" = "curl" ]; then
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- curl -s -X POST ${auth_header} "${base_url}/collections/${collection}/snapshots"
  else
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- wget -q -O- --method=POST ${auth_header} "${base_url}/collections/${collection}/snapshots"
  fi
}

getSnapshots() {
  local base_url="$1"
  local collection="$2"
  local auth_header="$3"
  
  if [ "$HTTP_CLIENT" = "curl" ]; then
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- curl -s ${auth_header} "${base_url}/collections/${collection}/snapshots" | jq -r '.result[].name' 2>/dev/null || echo ""
  else
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- wget -q -O- ${auth_header} "${base_url}/collections/${collection}/snapshots" | jq -r '.result[].name' 2>/dev/null || echo ""
  fi
}

downloadSnapshot() {
  local base_url="$1"
  local collection="$2"
  local snapshot="$3"
  local auth_header="$4"
  local output_path="$5"
  
  if [ "$HTTP_CLIENT" = "curl" ]; then
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- curl -s ${auth_header} "${base_url}/collections/${collection}/snapshots/${snapshot}" -o "${output_path}"
  else
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- wget -q ${auth_header} "${base_url}/collections/${collection}/snapshots/${snapshot}" -O "${output_path}"
  fi
}

uploadSnapshot() {
  local base_url="$1"
  local collection="$2"
  local snapshot_path="$3"
  local auth_header="$4"
  
  if [ "$HTTP_CLIENT" = "curl" ]; then
    kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- curl -s -X PUT ${auth_header} "${base_url}/collections/${collection}/snapshots/upload" --data-binary "@${snapshot_path}"
  else
    echo "Snapshot upload not supported with wget. Use curl instead."
    return 1
  fi
}

hasQdrantCli() {
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- test -x /qdrant/qdrant
}

checkDiskSpace () {
  local PATH_TO_CHECK="$1"
  local MIN_SPACE_MB=1024  # 1GB minimum for snapshots
  
  # Get available space in MB
  AVAILABLE_SPACE=$(kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- df -BM "$PATH_TO_CHECK" | tail -1 | awk '{print $4}' | sed 's/M//')
  
  if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_MB" ]; then
    printf "\n${COLOR_YELLOW}Warning.${COLOR_OFF} Low disk space on ${PATH_TO_CHECK}: ${AVAILABLE_SPACE}MB available (minimum recommended: ${MIN_SPACE_MB}MB).\n"
    printf "The snapshot might fail if the data is too large.\n\n"
    printf "${COLOR_BLUE}Tip:${COLOR_OFF} Consider using 'dump_forward' mode instead, which dumps directly to your local machine\n"
    printf "without requiring space in the container. Example:\n"
    printf "  $0 -m dump_forward -t ${TARGET} -o ${EXPORT_DIR}\n\n"
    read -p "Do you want to continue with 'dump' mode anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      printf "\n${COLOR_RED}Abort.${COLOR_OFF} Operation cancelled by user.\n"
      exit 1
    fi
  else
    printf "\n${COLOR_GREEN}Disk space check:${COLOR_OFF} ${AVAILABLE_SPACE}MB available on ${PATH_TO_CHECK}.\n"
  fi
}

# Parse options
while getopts ha:c:r:f:m:n:o:p:t: flag; do
  case "${flag}" in
    a)
      API_KEY=${OPTARG};;
    c)
      CONTAINER_NAME=${OPTARG};;
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
    h | *)
      print_help
      exit 0;;
  esac
done

# Init
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"
[[ ! -z "$API_KEY" ]] && AUTH_HEADER="-H 'api-key: $API_KEY'"
BASE_URL="http://localhost:${QDRANT_PORT}"

if [[ "$TARGET" == svc/* || "$TARGET" == service/* ]]; then
  SERVICE_NAME="${TARGET#*/}"
  POD_NAME=$(getPodFromService "$SERVICE_NAME")
  if [[ -z "$POD_NAME" ]]; then
    echo "No pods found for service : $SERVICE_NAME"
    exit 1
  fi
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
  > API_KEY: $(if [ -n "$API_KEY" ]; then printf "%*s" $(( ${#API_KEY} - 3 )) "" | tr " " "*"; echo "${API_KEY: -3}"; else echo "none"; fi)
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
  > QDRANT_PORT: ${QDRANT_PORT}
"

# Options validation
if [ -z "$MODE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: mode (flag -m)".
  exit 1
elif [ -z "$TARGET" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: target pod or service (flag -t)".
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: dump file or directory (flag -f)".
  exit 1
fi

# Check for dependencies based on mode
if [ "$MODE" = "dump" ] || [ "$MODE" = "restore" ]; then
  # CLI modes - check for Qdrant CLI and writable paths
  if ! hasQdrantCli; then
    printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Error: Qdrant CLI not found at /qdrant/qdrant in container.\n"
    printf "${COLOR_YELLOW}Recommendation: Use port forwarding modes instead:${COLOR_OFF}\n"
    printf "  - For backup: ./backup-kube-qdrant.sh -m dump_forward -t ${TARGET}\n"
    printf "  - For restore: ./backup-kube-qdrant.sh -m restore_forward -t ${TARGET} -f <backup_file>\n\n"
    exit 1
  fi
  
  for P in ${PATHS[*]}; do
    if [ "$(isRW $P)" = true ]; then
      DUMP_PATH=$P
      break
    fi
  done
  if [ -z $DUMP_PATH ]; then
    printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Error: Container filesystem is read-only for paths ${PATHS[*]}.\n\n"
    exit 1
  fi
elif [ "$MODE" != "dump_forward" ] && [ "$MODE" != "restore_forward" ] && [ "$MODE" != "list" ]; then
  # Legacy API modes - check for HTTP client
  if ! hasHttpClient; then
    printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Error: No HTTP client (curl or wget) found in container.\n"
    printf "${COLOR_YELLOW}Recommendation: Use CLI or port forwarding modes instead:${COLOR_OFF}\n"
    printf "  - For backup: ./backup-kube-qdrant.sh -m dump -t ${TARGET}\n"
    printf "  - For backup: ./backup-kube-qdrant.sh -m dump_forward -t ${TARGET}\n"
    printf "  - For restore: ./backup-kube-qdrant.sh -m restore -t ${TARGET} -f <backup_file>\n"
    printf "  - For restore: ./backup-kube-qdrant.sh -m restore_forward -t ${TARGET} -f <backup_file>\n\n"
    exit 1
  fi
fi

# List collections
if [ "$MODE" = "list" ]; then
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Listing collections.\n\n"
  
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:${QDRANT_PORT} &
  sleep 2
  
  COLLECTIONS=$(curl -s ${AUTH_HEADER} "http://127.0.0.1:5555/collections" | jq -r '.result.collections[].name' 2>/dev/null)
  
  if [ -n "$COLLECTIONS" ]; then
    printf "${COLOR_GREEN}Available collections:${COLOR_OFF}\n"
    echo "$COLLECTIONS" | while read -r collection; do
      printf "  - %s\n" "$collection"
    done
  else
    printf "${COLOR_YELLOW}No collections found or unable to connect.${COLOR_OFF}\n"
  fi
  
  kill %1 2>/dev/null || true

# Create snapshots using Qdrant CLI and copy locally
elif [ "$MODE" = "dump" ]; then
  # Check available disk space in container
  checkDiskSpace "$DUMP_PATH"

  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  BACKUP_DIR="${EXPORT_DIR}/${DATE_TIME}-qdrant"
  SNAPSHOT_FILE="storage-snapshot.tar"
  DESTINATION_DUMP="${BACKUP_DIR}/${SNAPSHOT_FILE}"
  mkdir -p "$BACKUP_DIR"

  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Creating storage snapshot using Qdrant CLI.\n\n"
  
  # Create snapshot using Qdrant CLI
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- /qdrant/qdrant --storage-snapshot "${DUMP_PATH}/${SNAPSHOT_FILE}"

  # Copy snapshot locally
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Copying snapshot locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${POD_NAME}:${DUMP_PATH}/${SNAPSHOT_FILE} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

  # Clean up snapshot from pod
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Cleaning up snapshot file from container.\n\n"
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- rm -f "${DUMP_PATH}/${SNAPSHOT_FILE}"
  printf "${COLOR_GREEN}Done.${COLOR_OFF} Snapshot file removed from container.\n"

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  BACKUP_DIR="${EXPORT_DIR}/${DATE_TIME}-qdrant"
  mkdir -p "$BACKUP_DIR"

  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Creating snapshots using port forward.\n\n"
  
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:${QDRANT_PORT} &
  sleep 2

  # Get collections to backup
  if [ -n "$COLLECTION_NAME" ]; then
    COLLECTIONS="$COLLECTION_NAME"
  else
    COLLECTIONS=$(curl -s ${AUTH_HEADER} "http://127.0.0.1:5555/collections" | jq -r '.result.collections[].name' 2>/dev/null)
    if [ -z "$COLLECTIONS" ]; then
      printf "\n\n${COLOR_RED}[Backup wrapper].${COLOR_OFF} Error: No collections found or unable to connect.\n\n"
      kill %1 2>/dev/null || true
      exit 1
    fi
  fi

  # Create and download snapshots for each collection
  for collection in $COLLECTIONS; do
    printf "\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Processing collection: ${collection}\n"
    
    # Create snapshot
    SNAPSHOT_RESULT=$(curl -s -X POST ${AUTH_HEADER} "http://127.0.0.1:5555/collections/${collection}/snapshots")
    SNAPSHOT_NAME=$(echo "$SNAPSHOT_RESULT" | jq -r '.result.name' 2>/dev/null)
    
    if [ -z "$SNAPSHOT_NAME" ] || [ "$SNAPSHOT_NAME" = "null" ]; then
      printf "${COLOR_RED}Error creating snapshot for collection: ${collection}${COLOR_OFF}\n"
      continue
    fi
    
    # Download snapshot
    LOCAL_SNAPSHOT="${BACKUP_DIR}/${collection}-${SNAPSHOT_NAME}"
    printf "${COLOR_GREEN}Downloading snapshot: ${LOCAL_SNAPSHOT}${COLOR_OFF}\n"
    curl -s ${AUTH_HEADER} "http://127.0.0.1:5555/collections/${collection}/snapshots/${SNAPSHOT_NAME}" -o "${LOCAL_SNAPSHOT}"
  done

  kill %1 2>/dev/null || true

# Restore snapshots using Qdrant CLI
elif [ "$MODE" = "restore" ]; then
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Restoring storage snapshot using Qdrant CLI.\n\n"

  # Copy local snapshot into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Copy local snapshot file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore using Qdrant CLI
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Restore storage snapshot.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- /qdrant/qdrant --storage-snapshot ${DUMP_PATH}/${DUMP_FILE_BASENAME} --force-snapshot

  # Clean up
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- rm -f "${DUMP_PATH}/${DUMP_FILE_BASENAME}"

elif [ "$MODE" = "restore_forward" ]; then
  printf "\n\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Restoring snapshots using port forward.\n\n"
  
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:${QDRANT_PORT} &
  sleep 2

  if [ -d "$DUMP_FILE" ]; then
    # Restore from directory
    for snapshot_file in "$DUMP_FILE"/*; do
      [ -f "$snapshot_file" ] || continue
      
      filename=$(basename "$snapshot_file")
      collection=$(echo "$filename" | cut -d'-' -f1)
      
      printf "\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Restoring collection: ${collection}\n"
      
      # Upload snapshot
      curl -s -X PUT ${AUTH_HEADER} "http://127.0.0.1:5555/collections/${collection}/snapshots/upload" --data-binary "@${snapshot_file}"
    done
  else
    # Restore single file
    filename=$(basename "$DUMP_FILE")
    collection=$(echo "$filename" | cut -d'-' -f1)
    
    printf "\n${COLOR_BLUE}[Backup wrapper].${COLOR_OFF} Restoring collection: ${collection}\n"
    
    # Upload snapshot
    curl -s -X PUT ${AUTH_HEADER} "http://127.0.0.1:5555/collections/${collection}/snapshots/upload" --data-binary "@${DUMP_FILE}"
  fi

  kill %1 2>/dev/null || true
fi

printf "\n\n${COLOR_GREEN}[Backup wrapper].${COLOR_OFF} Operation completed successfully.\n\n"
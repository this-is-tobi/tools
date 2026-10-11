#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
NAMESPACE=""
CONTAINER_NAME=""
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
DUMP_PATH=""
DUMP_FILE=""
MODE=""
TARGET=""
VAULT_TOKEN="${VAULT_TOKEN:-}"
NAMESPACE_ARG=""
CONTAINER_ARG=""
POD_NAME=""
SERVICE_NAME=""
VAULT_PORT="8200"
LOCAL_PORT=""
PF_PID=""
PF_LOG=""
LOCAL_TMP_PATHS=()
POD_TMP_PATHS=()
PATHS=(
  /vault/data
  /bitnami/vault/data
  /tmp
)

# Script helper
TEXT_HELPER="
This script aims to perform a dump on a kubernetes vault pod and copy locally the dump file, or the opposite, restore a local dump file to a vault pod.

Available flags:
  -c    Name of the pod's container.
  -f    Local dump file to restore (only needed with restore mode).
  -m    Mode tu run. Available modes are:
          dump              - Dump the vault locally.
          dump_forward      - Dump the vault locally with port forward.
          restore           - Restore local dump into pod.
          restore_forward   - Restore local dump with port forward.
  -n    Kubernetes namespace target where the vault pod is running.
        Default: the namespace of the current kubectl context.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Token used to connect to the vault server.
        Prefer the VAULT_TOKEN environment variable: a -p value shows in the local process list.
  -t    Target name of the pod or service to run the dump on.
  -h    Print script help.

The token never reaches a command line and is never written to a ~/.vault-token file: it is sent
to the pod on stdin, or exported as VAULT_TOKEN for the local vault CLI in the *_forward modes.
Those modes forward a random free local port to the pod's port $VAULT_PORT and detect whether it
serves https or http.

Example:
  VAULT_TOKEN='mytoken' ./backup-kube-vault.sh \\
    -m 'dump' \\
    -t 'my-vault-pod' \\
    -o './backups'

  VAULT_TOKEN='mytoken' ./backup-kube-vault.sh \\
    -m 'restore' \\
    -t 'my-vault-pod' \\
    -f './backups/20240101T1200-vault.snap'
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
  if [ ${#POD_TMP_PATHS[@]} -gt 0 ]; then
    podExec rm -f "${POD_TMP_PATHS[@]}" >/dev/null 2>&1 || true
  fi
  exit "$STATUS"
}

podExec () {
  kubectl ${NAMESPACE_ARG} exec "$POD_NAME" ${CONTAINER_ARG} -- "$@"
}

# Runs a vault command in the container with the token exported as VAULT_TOKEN. The token
# travels on stdin so it never shows in a process list or in the Kubernetes API audit log, and
# 'vault login' is not used because it would store the token in the container's ~/.vault-token.
podVault () {
  printf '%s' "$VAULT_TOKEN" | kubectl ${NAMESPACE_ARG} exec -i "$POD_NAME" ${CONTAINER_ARG} -- \
    sh -c 'VAULT_TOKEN=$(cat); export VAULT_TOKEN; exec vault "$@"' sh "$@"
}

isRW () {
  podExec sh -c '[ -w "$1" ] && echo true || echo false' sh "$1"
}

getPodFromService () {
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

# Forwards a random free local port to the pod's vault port and waits for the tunnel to listen,
# so the vault CLI talks to the forwarded pod and never to whatever listens locally on 8200.
startPortForward () {
  local TRIES=0
  PF_LOG="$(mktemp)"
  kubectl ${NAMESPACE_ARG} port-forward --address 127.0.0.1 "pod/${POD_NAME}" ":${VAULT_PORT}" > "$PF_LOG" 2>&1 &
  PF_PID=$!
  while true; do
    LOCAL_PORT="$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9][0-9]*\) .*/\1/p' "$PF_LOG" | head -n 1)"
    [ -n "$LOCAL_PORT" ] && break
    if ! kill -0 "$PF_PID" 2>/dev/null || [ "$TRIES" -ge 30 ]; then
      cat "$PF_LOG" >&2
      error "Port forward to pod '${POD_NAME}' (port ${VAULT_PORT}) did not start."
      exit 1
    fi
    TRIES=$((TRIES + 1))
    sleep 1
  done
  printf "Forwarding 127.0.0.1:%s to pod '%s' port %s.\n" "$LOCAL_PORT" "$POD_NAME" "$VAULT_PORT"
}

# Finds the scheme served through the tunnel and sets LOCAL_VAULT_ADDR. 'vault status' exits 0
# when unsealed, 2 when sealed and 1 when it cannot talk to the server.
detectLocalVaultAddr () {
  local SCHEME RC
  LOCAL_VAULT_ADDR=""
  for SCHEME in https http; do
    RC=0
    vault status -address="${SCHEME}://127.0.0.1:${LOCAL_PORT}" -tls-skip-verify >/dev/null 2>&1 || RC=$?
    if [ "$RC" -eq 0 ] || [ "$RC" -eq 2 ]; then
      LOCAL_VAULT_ADDR="${SCHEME}://127.0.0.1:${LOCAL_PORT}"
      return 0
    fi
  done
  error "Vault does not answer through the port forward (tried https and http on 127.0.0.1:${LOCAL_PORT}, is the vault CLI installed?)."
  exit 1
}

checkDiskSpace () {
  local PATH_TO_CHECK="$1"
  local MIN_SPACE_MB=1024  # 1GB minimum for snapshots

  # Get available space in MB (-P = POSIX format, prevents line-wrapping for long device names)
  AVAILABLE_SPACE=$(podExec df -Pk "$PATH_TO_CHECK" | tail -1 | awk '{print int($4/1024)}')

  if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_MB" ]; then
    printf "\n${COLOR_YELLOW}Warning.${COLOR_OFF} Low disk space on ${PATH_TO_CHECK}: ${AVAILABLE_SPACE}MB available (minimum recommended: ${MIN_SPACE_MB}MB).\n"
    printf "The snapshot might fail if the vault data is too large.\n\n"
    printf "${COLOR_BLUE}Tip:${COLOR_OFF} Consider using 'dump_forward' mode instead, which dumps directly to your local machine\n"
    printf "without requiring space in the container. Example:\n"
    printf "  $0 -m dump_forward -t ${TARGET} -o ${EXPORT_DIR}\n\n"
    # Read the answer from the terminal: with 'curl ... | bash' stdin is the script itself
    REPLY=""
    read -p "Do you want to continue with 'dump' mode anyway? (y/N): " -n 1 -r < /dev/tty || REPLY=""
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      printf "\n${COLOR_RED}Abort.${COLOR_OFF} Operation cancelled by user.\n"
      exit 1
    fi
  else
    printf "\n${COLOR_GREEN}Disk space check:${COLOR_OFF} ${AVAILABLE_SPACE}MB available on ${PATH_TO_CHECK}.\n"
  fi
}

# 'vault status' needs no token, so this never sends one
getLeaderAddress () {
  local LEADER_ADDR=""
  # Try https first, then http to handle both TLS and non-TLS vault setups
  for SCHEME in https http; do
    LEADER_ADDR=$(podExec vault status -format=json -tls-skip-verify -address="${SCHEME}://127.0.0.1:${VAULT_PORT}" \
      2>/dev/null | jq -r '.leader_address // empty' 2>/dev/null || true)
    if [[ -n "$LEADER_ADDR" ]]; then
      echo "$LEADER_ADDR"
      return 0
    fi
  done
  echo ""
}

# Parse options
while getopts hc:f:m:n:o:p:t: flag; do
  case "${flag}" in
    c)
      CONTAINER_NAME=${OPTARG};;
    f)
      DUMP_FILE=${OPTARG};;
    m)
      MODE=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    o)
      EXPORT_DIR=${OPTARG};;
    p)
      VAULT_TOKEN=${OPTARG};;
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
[[ -n "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"

# Options validation
if [ -z "$MODE" ]; then
  error "Argument missing: mode (flag -m)."
  exit 1
elif [ "$MODE" != "dump" ] && [ "$MODE" != "dump_forward" ] && [ "$MODE" != "restore" ] && [ "$MODE" != "restore_forward" ]; then
  error "Unknown mode '$MODE' (flag -m)."
  exit 1
elif [ -z "$TARGET" ]; then
  error "Argument missing: target pod or service (flag -t)."
  exit 1
elif [ -z "$VAULT_TOKEN" ]; then
  error "Argument missing: vault token (VAULT_TOKEN environment variable or flag -p)."
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  error "Argument missing: dump file (flag -f)."
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ ! -f "$DUMP_FILE" ]; then
  error "Dump file '$DUMP_FILE' not found (flag -f)."
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
  > VAULT_TOKEN: $([ -n "$VAULT_TOKEN" ] && echo 'set' || echo 'not set')
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
"

if [ "$MODE" = "dump" ] || [ "$MODE" = "restore" ]; then
  for P in "${PATHS[@]}"; do
    if [ "$(isRW "$P")" = true ]; then
      DUMP_PATH=$P
      break
    fi
  done
  if [ -z "$DUMP_PATH" ]; then
    printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Error: Container filesystem is read-only for paths ${PATHS[*]}.\n\n" >&2
    exit 1
  fi
fi

# Dump vault
if [ "$MODE" = "dump" ]; then
  # Check available disk space in container
  checkDiskSpace "$DUMP_PATH"

  # Create output directory
  mkdir -p "$EXPORT_DIR"

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"
  POD_DUMP="${DUMP_PATH}/${DUMP_FILENAME}"

  # Get vault leader address
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Getting vault leader address.\n\n"
  LEADER_ADDRESS=$(getLeaderAddress)
  VAULT_ADDR_ARG=""
  if [[ -n "$LEADER_ADDRESS" ]]; then
    printf "${COLOR_GREEN}Leader address:${COLOR_OFF} ${LEADER_ADDRESS}\n"
    VAULT_ADDR_ARG="-address=${LEADER_ADDRESS}"
  else
    printf "${COLOR_YELLOW}Warning.${COLOR_OFF} Could not determine vault leader address, using default.\n"
  fi

  # Dump vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump vault.\n\n"
  POD_TMP_PATHS=("$POD_DUMP")
  podVault operator raft snapshot save -tls-skip-verify ${VAULT_ADDR_ARG:+"$VAULT_ADDR_ARG"} "$POD_DUMP"

  # Copy dump locally, under a temporary name until the copy is complete
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  LOCAL_TMP_PATHS=("${DESTINATION_DUMP}.partial")
  kubectl ${NAMESPACE_ARG} cp "${POD_NAME}:${POD_DUMP}" "${DESTINATION_DUMP}.partial" ${CONTAINER_ARG}
  mv "${DESTINATION_DUMP}.partial" "$DESTINATION_DUMP"
  LOCAL_TMP_PATHS=()

  # Clean up dump file from container
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Cleaning up dump file from container.\n\n"
  podExec rm -f "$POD_DUMP"
  POD_TMP_PATHS=()
  printf "${COLOR_GREEN}Done.${COLOR_OFF} Dump file removed from container.\n"

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Vault dump ended successfully.\n\n"

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  mkdir -p "$EXPORT_DIR"

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump vault locally (path: '${DESTINATION_DUMP}').\n\n"
  startPortForward
  detectLocalVaultAddr
  export VAULT_TOKEN
  # The server certificate names the vault service, not 127.0.0.1, and the traffic already runs
  # inside the authenticated kubectl tunnel, hence -tls-skip-verify as in the in-pod modes.
  LOCAL_TMP_PATHS=("${DESTINATION_DUMP}.partial")
  vault operator raft snapshot save -address="$LOCAL_VAULT_ADDR" -tls-skip-verify "${DESTINATION_DUMP}.partial"
  mv "${DESTINATION_DUMP}.partial" "$DESTINATION_DUMP"
  LOCAL_TMP_PATHS=()

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Vault dump ended successfully.\n\n"

# Restore vault
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename "$DUMP_FILE")"
  POD_DUMP="${DUMP_PATH}/${DUMP_FILE_BASENAME}"
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy local dump file into container (path: '$POD_DUMP').\n\n"
  POD_TMP_PATHS=("$POD_DUMP")
  kubectl ${NAMESPACE_ARG} cp "$DUMP_FILE" "${POD_NAME}:${POD_DUMP}" ${CONTAINER_ARG}

  # Restore vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore vault.\n\n"
  podVault operator raft snapshot restore "$POD_DUMP"

  podExec rm -f "$POD_DUMP"
  POD_TMP_PATHS=()

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Vault restore ended successfully.\n\n"

elif [ "$MODE" = "restore_forward" ]; then
  # Restore vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore vault.\n\n"
  startPortForward
  detectLocalVaultAddr
  export VAULT_TOKEN
  vault operator raft snapshot restore -address="$LOCAL_VAULT_ADDR" -tls-skip-verify "$DUMP_FILE"

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Vault restore ended successfully.\n\n"
fi

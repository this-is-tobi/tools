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
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
DUMP_PATH=""
DUMP_FILE=""
MODE=""
TARGET=""
VAULT_TOKEN=""
NAMESPACE_ARG=""
CONTAINER_ARG=""
POD_NAME=""
SERVICE_NAME=""
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
        Default: current namespace '$NAMESPACE'.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Token used to connect to the vault server.
  -t    Target name of the pod or service to run the dump on.
  -h    Print script help.

Example:
  ./backup-kube-vault.sh \\
    -m 'dump' \\
    -t 'my-vault-pod' \\
    -p 'mytoken' \\
    -o './backups'

  ./backup-kube-vault.sh \\
    -m 'restore' \\
    -t 'my-vault-pod' \\
    -f './backups/20240101T1200-vault.snap' \\
    -p 'mytoken'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

isRW () {
  kubectl $NAMESPACE_ARG exec ${POD_NAME} -- sh -c "[ -w $1 ] && echo 'true' || echo 'false'"
}

getPodFromService () {
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

checkDiskSpace () {
  local PATH_TO_CHECK="$1"
  local MIN_SPACE_MB=1024  # 1GB minimum for snapshots
  
  # Get available space in MB
  AVAILABLE_SPACE=$(kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- df -BM "$PATH_TO_CHECK" | tail -1 | awk '{print $4}' | sed 's/M//')
  
  if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_MB" ]; then
    printf "\n${COLOR_YELLOW}Warning.${COLOR_OFF} Low disk space on ${PATH_TO_CHECK}: ${AVAILABLE_SPACE}MB available (minimum recommended: ${MIN_SPACE_MB}MB).\n"
    printf "The snapshot might fail if the vault data is too large.\n\n"
    printf "${COLOR_BLUE}Tip:${COLOR_OFF} Consider using 'dump_forward' mode instead, which dumps directly to your local machine\n"
    printf "without requiring space in the container. Example:\n"
    printf "  $0 -m dump_forward -t ${TARGET} -p '***' -o ${EXPORT_DIR}\n\n"
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
    h | *)
      print_help
      exit 0;;
  esac
done

# Init
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"

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
  > VAULT_TOKEN: $(printf "%*s" $(( ${#VAULT_TOKEN} - 3 )) "" | tr " " "*")${VAULT_TOKEN: -3}
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
"

# Options validation
if [ -z "$MODE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: mode (flag -m)".
  exit 1
elif [ -z "$TARGET" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: target pod or service (flag -t)".
  exit 1
elif [ -z "$VAULT_TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: vault token (flag -p)".
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: dump file (flag -f)".
  exit 1
fi
if [ ! "$MODE" = "dump_forward" ]; then
  for P in ${PATHS[*]}; do
    if [ "$(isRW $P)" = true ]; then
      DUMP_PATH=$P
      break
    fi
  done
  if [ -z $DUMP_PATH ]; then
    printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Error: Container filesystem is read-only for paths $PATHS.\n\n"
    exit 1
  fi
fi

# Dump vault
if [ "$MODE" = "dump" ]; then
  # Check available disk space in container
  checkDiskSpace "$DUMP_PATH"

  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump vault.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot save ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

  # Clean up dump file from container
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Cleaning up dump file from container.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- rm -f "${DUMP_PATH}/${DUMP_FILENAME}"
  printf "${COLOR_GREEN}Done.${COLOR_OFF} Dump file removed from container.\n"

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump vault locally (path: '${DESTINATION_DUMP}').\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:8200 &
  sleep 2
  echo ${VAULT_TOKEN} | vault login -address=https://127.0.0.1:8200 -non-interactive - \
    && vault operator raft snapshot save -address=https://127.0.0.1:8200 ${DESTINATION_DUMP}

  kill %1

# Restore vault
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore vault
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore vault.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot restore ${DUMP_PATH}/${DUMP_FILE_BASENAME}"

elif [ "$MODE" = "restore_forward" ]; then
  # Restore database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore database.\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:8200 &
  sleep 2
  echo ${VAULT_TOKEN} | vault login -address 127.0.0.1:5555 -non-interactive - \
    && vault operator raft snapshot restore -address=https://127.0.0.1:8200 ${DUMP_FILE}

  kill %1
fi

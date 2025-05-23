#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
NAMESPACE="$(kubectl config view --minify -o jsonpath='{..namespace}')"
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")

# Declare script helper
TEXT_HELPER="\nThis script aims to perform a dump on a kubernetes vault pod and copy locally the dump file, or the opposite, restore a local dump file to a vault pod.
Following flags are available:

  -c    Name of the pod's container.

  -f    Local dump file to restore (only needed with restore mode).

  -m    Mode tu run. Available modes are :
          dump              - Dump the vault locally.
          dump_forward      - Dump the vault locally with port forward.
          restore           - Restore local dump into pod.
          restore_forward   - Restore local dump with port forward.

  -n    Kubernetes namespace target where the vault pod is running.
        Default is current namespace : '$NAMESPACE'.

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'.

  -p    Token used to connect to the vault server.

  -t    Target name of the pod or service to run the dump on.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
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


if [ -z "$MODE" ]; then
  printf "\n${red}Error.${no_color} Argument missing: mode (flag -m)".
  exit 1
elif [ -z "$TARGET" ]; then
  printf "\n${red}Error.${no_color} Argument missing: target pod or service (flag -t)".
  exit 1
elif [ -z "$VAULT_TOKEN" ]; then
  printf "\n${red}Error.${no_color} Argument missing: vault token (flag -p)".
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${red}Error.${no_color} Argument missing: dump file (flag -f)".
  exit 1
fi


# Add namespace if provided
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"


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


printf "Settings:
  > MODE: ${MODE}
  > EXPORT_DIR: ${EXPORT_DIR}
  > DUMP_FILE: ${DUMP_FILE}
  > VAULT_TOKEN: $(printf "%*s" $(( ${#VAULT_TOKEN} - 3 )) "" | tr " " "*")${VAULT_TOKEN: -3}
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}\n"

DUMP_PATH=""
PATHS=(
  /vault/data
  /bitnami/vault/data
  /tmp
)

# Check container fs permissions to store the dump file
if [ ! "$MODE" = "dump_forward" ]; then
  for P in ${PATHS[*]}; do
    if [ "$(isRW $P)" = true ]; then
      DUMP_PATH=$P
      break
    fi
  done
  if [ -z $DUMP_PATH ]; then
    printf "\n\n${red}[Dump wrapper].${no_color} Error: Container filesystem is read-only for paths $PATHS.\n\n"
    exit 1
  fi
fi


# Dump vault
if [ "$MODE" = "dump" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${red}[Dump wrapper].${no_color} Dump vault.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot save ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${red}[Dump wrapper].${no_color} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${red}[Dump wrapper].${no_color} Dump vault locally (path: '${DESTINATION_DUMP}').\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:8200 &
  sleep 1
  echo ${VAULT_TOKEN} | vault login -address=https://127.0.0.1:8200 -non-interactive - \
    && vault operator raft snapshot save -address=https://127.0.0.1:8200 ${DESTINATION_DUMP}

  kill %1

# Restore vault
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${red}[Dump wrapper].${no_color} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore vault
  printf "\n\n${red}[Dump wrapper].${no_color} Restore vault.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot restore ${DUMP_PATH}/${DUMP_FILE_BASENAME}"

elif [ "$MODE" = "restore_forward" ]; then
  # Restore database
  printf "\n\n${red}[Dump wrapper].${no_color} Restore database.\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:8200 &
  sleep 1
  echo ${VAULT_TOKEN} | vault login -address 127.0.0.1:5555 -non-interactive - \
    && vault operator raft snapshot restore -address=https://127.0.0.1:8200 ${DUMP_FILE}

  kill %1
fi

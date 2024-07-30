#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")

# Declare script helper
TEXT_HELPER="\nThis script aims to perform a dump on a kubernetes vault pod and copy locally the dump file, or the opposite, restore a local dump file to a vault pod.
Following flags are available:

  -c    Name of the pod's container.

  -f    Local dump file to restore (only needed with restore mode).

  -m    Mode tu run. Available modes are :
          dump            - Dump the vault locally.
          dump_forward    - Dump the vault locally with port forward.
          restore         - Restore local dump into pod.

  -n    Kubernetes namespace target where the vault pod is running.
        Default is '$NAMESPACE'.

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'.

  -p    Name of the pod to run the dump on.

  -t    Token used to connect to the vault server.

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
      POD_NAME=${OPTARG};;
    t)
      VAULT_TOKEN=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done


if [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ] && [ -z "$POD_NAME" ]; then
  printf "\n${red}Error.${no_color} Argument missing : pod name (flag -r)".
  exit 1
elif [ "$MODE" = "restore" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${red}Error.${no_color} Argument DUMP_FILE : vault file dump (flag -f)".
  exit 1
fi


# Add namespace if provided
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"


isRW () {
  kubectl $NAMESPACE_ARG exec ${POD_NAME} -- sh -c "[ -w $1 ] && echo 'true' || echo 'false'"
}


printf "Settings:
  > MODE: ${MODE}
  > NAMESPACE: ${NAMESPACE:-$(kubectl config view --minify -o jsonpath='{..namespace}')}
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
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot save ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${red}[Dump wrapper].${no_color} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl $NAMESPACE_ARG cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-vault.snap"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump vault
  printf "\n\n${red}[Dump wrapper].${no_color} Dump vault locally (path: '${DESTINATION_DUMP}').\n\n"
  set +e
  kubectl $NAMESPACE_ARG port-forward ${POD_NAME} 5555:8200 &
  sleep 1
  echo ${VAULT_TOKEN} | vault login -address=https://127.0.0.1:8200 -non-interactive - \
    && vault operator raft snapshot save -address=https://127.0.0.1:8200 ${DESTINATION_DUMP}

  kill %1

# Restore vault
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${red}[Dump wrapper].${no_color} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl $NAMESPACE_ARG cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore vault
  printf "\n\n${red}[Dump wrapper].${no_color} Restore vault.\n\n"
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- sh -c "echo ${VAULT_TOKEN} | vault login -non-interactive - && vault operator raft snapshot restore ${DUMP_PATH}/${DUMP_FILENAME}"
fi

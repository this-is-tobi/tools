#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
DB_USER="postgres"
EXPORT_DIR="./db-dumps"
DATE_TIME=$(date +"%Y-%m-%dT%H-%M")

# Declare script helper
TEXT_HELPER="\nThis script aims to perform a dump on a kubernetes postgres pod and copy locally the dump file.
Following flags are available:

  -c    Name of the pod's container.

  -d    Name of the postgres database.

  -f    Local dump file to restore.

  -m    Mode tu run. Available modes are :
          dump            - Dump the database locally.
          dump_forward    - Dump the database locally with port forward.
          restore         - Restore local dump into pod.

  -n    Kubernetes namespace target where the database pod is running.
        Default is '$NAMESPACE'

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'

  -p    Password of the database user that will run the dump command.

  -r    Name of the pod to run the dump on.

  -u    Database user used to dump the database.
        Default is '$DB_USER'

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:m:n:o:p:r:u: flag; do
  case "${flag}" in
    c)
      CONTAINER_NAME=${OPTARG};;
    d)
      DB_NAME=${OPTARG};;
    f)
      DUMP_FILE=${OPTARG};;
    m)
      MODE=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    o)
      EXPORT_DIR=${OPTARG};;
    p)
      DB_PASS=${OPTARG};;
    r)
      POD_NAME=${OPTARG};;
    u)
      DB_USER=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done


if [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ] && [ -z "$POD_NAME" ]; then
  printf "\n${red}Error.${no_color} Argument missing : pod name (flag -r)".
  exit 1
elif [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ] && [ -z "$DB_NAME" ]; then
  printf "\n${red}Error.${no_color} Argument missing : database name (flag -d)".
  exit 1
elif [ "$MODE" = "restore" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${red}Error.${no_color} Argument DUMP_FILE : database file dump (flag -f)".
  exit 1
fi


# Add namespace if provided
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"
[[ ! -z "$DB_NAME" ]] && DB_NAME_ARG="-d $DB_NAME"


isRW () {
  kubectl $NAMESPACE_ARG exec ${POD_NAME} -- bash -c "[ -w $1 ] && echo 'true' || echo 'false'"
}


printf "Settings:
  > MODE: ${MODE}
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > DB_PASS: ${DB_PASS}
  > NAMESPACE: ${NAMESPACE:-$(kubectl config view --minify -o jsonpath='{..namespace}')}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}\n"

DUMP_PATH=""
PATHS=(
  /tmp
  /var/lib/postgresql/data
  /bitnami/postgresql/data
)

# Check container fs permissions to store the dump file
if [ ! "$MODE" = "dump_forward" ]; then
  for P in ${PATHS[*]}; do
    if [ "$(isRW $P)" = true ]; then
      DUMP_PATH=$P
      break
    fi
  done
fi

if [ -z $DUMP_PATH ]; then
  printf "\n\n${red}[Dump wrapper].${no_color} Error: Container filesystem is read-only for path '/tmp', '/var/lib/postgresql/data' and '/bitnami/postgresql/data'.\n\n"
  exit 1
fi


# Dump database
if [ "$MODE" = "dump" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}_${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${red}[Dump wrapper].${no_color} Dump database.\n\n"
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' pg_dump -Fc -U '${DB_USER}' '${DB_NAME}' > ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${red}[Dump wrapper].${no_color} Copy dump file locally.\n\n"
  kubectl $NAMESPACE_ARG cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}"  ${CONTAINER_ARG}

  echo ${DESTINATION_DUMP}

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}_${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  echo $DESTINATION_DUMP
  # Dump database
  printf "\n\n${red}[Dump wrapper].${no_color} Dump database.\n\n"
  set +e
  kubectl $NAMESPACE_ARG port-forward ${POD_NAME} 5555:5432 &
  sleep 1
  PGPASSWORD=${DB_PASS} pg_dump -Fc -U ${DB_USER} -p 5555 -h 127.0.0.1 ${DB_NAME} > ${DESTINATION_DUMP}

  kill %1
  echo ${DESTINATION_DUMP}

# Restore database
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${red}[Dump wrapper].${no_color} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl $NAMESPACE_ARG cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore database
  printf "\n\n${red}[Dump wrapper].${no_color} Restore database.\n\n"
  kubectl $NAMESPACE_ARG exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' pg_restore -Fc ${DB_NAME_ARG} ${DUMP_PATH}/${DUMP_FILE_BASENAME} -U '${DB_USER}'"
fi

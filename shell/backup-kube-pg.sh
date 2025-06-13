#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
NAMESPACE="$(kubectl config view --minify -o jsonpath='{..namespace}')"
DB_USER="postgres"
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
CLEAN_RESTORE="false"

# Declare script helper
TEXT_HELPER="\nThis script aims to perform a dump on a kubernetes postgres pod and copy locally the dump file, or the opposite, restore a local dump file to a postgres pod.
Following flags are available:

  -c    Name of the pod's container.

  -d    Name of the postgres database.

  -f    Local dump file to restore (only needed with restore mode).

  -m    Mode tu run. Available modes are :
          dump              - Dump the database locally.
          dump_forward      - Dump the database locally with port forward.
          restore           - Restore local dump into pod.
          restore_forward   - Restore local dump with port forward.

  -n    Kubernetes namespace target where the database pod is running.
        Default is current namespace : '$NAMESPACE'.

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'.

  -p    Password of the database user that will run the dump command.

  -t    Target name of the pod or service to run the dump on.

  -u    Database user used to dump the database.
        Default is '$DB_USER'.

  -z    Drop the database if exists before restore.
        Default is '$CLEAN_RESTORE'.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:m:n:o:p:t:u:z flag; do
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
    t)
      TARGET=${OPTARG};;
    u)
      DB_USER=${OPTARG};;
    z)
      CLEAN_RESTORE="true";;
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
elif [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ] && [ -z "$DB_NAME" ]; then
  printf "\n${red}Error.${no_color} Argument missing: database name (flag -d)".
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${red}Error.${no_color} Argument missing: dump file (flag -f)".
  exit 1
fi


# Add namespace if provided
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"
[[ ! -z "$DB_NAME" ]] && DB_NAME_ARG="-d $DB_NAME"


isRW () {
  kubectl $NAMESPACE_ARG exec ${TARGET} -- bash -c "[ -w $1 ] && echo 'true' || echo 'false'"
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
  > EXPORT_DIR: $([ ${MODE} = 'dump' ] || [ ${MODE} = 'dump_forward' ] && ${EXPORT_DIR} || echo '-')
  > DUMP_FILE: $([ ${MODE} = 'restore' ] || [ ${MODE} = 'restore_forward' ] && ${DUMP_FILE} || echo '-')
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > DB_PASS: $(if [ -n $DB_PASS ]; then printf "%*s" $(( ${#DB_PASS} - 3 )) "" | tr " " "*"; echo ${DB_PASS: -3}; else echo ''; fi)
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
  > CLEAN_RESTORE: $([ ${MODE} = 'restore' ] || [ ${MODE} = 'restore_forward' ] && ${CLEAN_RESTORE} || echo '-')\n\n"


DUMP_PATH=""
PATHS=(
  /tmp
  /var/tmp
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
  if [ -z $DUMP_PATH ]; then
    printf "\n\n${red}[Dump wrapper].${no_color} Error: Container filesystem is read-only for paths $PATHS.\n\n"
    exit 1
  fi
fi


# Dump database
if [ "$MODE" = "dump" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${red}[Dump wrapper].${no_color} Dump database.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD=${DB_PASS} pg_dump -Fc -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} > ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${red}[Dump wrapper].${no_color} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${red}[Dump wrapper].${no_color} Dump database locally (path: '${DESTINATION_DUMP}').\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:5432 &
  sleep 1
  pg_dump -Fc -d postgresql://${DB_USER}:${DB_PASS}@localhost:5555/${DB_NAME} ${DB_NAME_ARG} > ${DESTINATION_DUMP}

  kill %1

# Restore database
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${red}[Dump wrapper].${no_color} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore database
  printf "\n\n${red}[Dump wrapper].${no_color} Restore database.\n\n"
  if [ "$CLEAN_RESTORE" = "true" ]; then
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' psql -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} -c 'DROP DATABASE  IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};'"
  fi
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "pg_restore -Fc -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} ${DUMP_PATH}/${DUMP_FILE_BASENAME}"
  if [ "$CLEAN_RESTORE" = "true" ]; then
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' psql -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} -c 'ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};'"
  fi

elif [ "$MODE" = "restore_forward" ]; then
  # Restore database
  printf "\n\n${red}[Dump wrapper].${no_color} Restore database.\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5555:5432 &
  sleep 1
  if [ "$CLEAN_RESTORE" = "true" ]; then
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' psql -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} -c 'DROP DATABASE  IF EXISTS ${DB_NAME}; CREATE DATABASE ${DB_NAME};'"
  fi
  pg_restore -Fc -d postgresql://${DB_USER}:${DB_PASS}@localhost:5555/${DB_NAME} ${DB_NAME_ARG} ${DUMP_FILE}
  if [ "$CLEAN_RESTORE" = "true" ]; then
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "PGPASSWORD='${DB_PASS}' psql -d postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME} -c 'ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};'"
  fi

  kill %1
fi

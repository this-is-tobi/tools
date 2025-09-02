#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
DB_USER="postgres"
DB_OWNER="postgres"
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
CLEAN_RESTORE="false"
DUMP_PATH=""
PATHS=(
  /tmp
  /var/tmp
  /var/lib/postgresql/data
  /bitnami/postgresql/data
)

# Script helper
TEXT_HELPER="
This script aims to perform a dump on a kubernetes postgres pod and copy locally the dump file, or the opposite, restore a local dump file to a postgres pod.

Available flags:
  -c    Name of the pod's container.
  -d    Name of the postgres database.
  -f    Local dump file to restore (only needed with restore mode).
  -m    Mode tu run. Available modes are:
          dump              - Dump the database locally.
          dump_forward      - Dump the database locally with port forward.
          restore           - Restore local dump into pod.
          restore_forward   - Restore local dump with port forward.
  -n    Kubernetes namespace target where the database pod is running.
        Default: current namespace '$NAMESPACE'.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Password of the database user that will run the dump / restore command.
  -t    Target name of the pod or service to run the dump / restore.
  -u    Database user used to dump / restore the database.
        Default: '$DB_USER'.
  -x    Owner of the postgres database when restore.
        Default: '$DB_OWNER'.
  -z    Close the connections, drop the database if exists and re-create it before restore.
  -h    Print script help.

Example:
  ./backup-kube-pg.sh \\
    -m 'dump' \\
    -t 'my-postgres-pod' \\
    -d 'mydatabase' \\
    -u 'myuser' \\
    -p 'mypassword' \\
    -o './backups'

  ./backup-kube-pg.sh \\
    -m 'restore' \\
    -t 'my-postgres-pod' \\
    -f './backups/20240101T1200-mydatabase.dump' \\
    -d 'mydatabase' \\
    -u 'myuser' \\
    -p 'mypassword' \\
    -x 'dbowner' \\
    -z
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

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

urlEncode () {
  jq -rn --arg x "$1" '$x | @uri'
}

getPgUri () {
  if [ -z ${DB_PASS} ]; then
    echo "postgresql://${DB_USER}@localhost:5432/$1"
  else
    echo "postgresql://${DB_USER}:$(urlEncode ${DB_PASS})@localhost:5432/$1"
  fi
}

# Parse options
while getopts hc:d:f:m:n:o:p:t:u:x:z flag; do
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
    x)
      DB_OWNER=${OPTARG};;
    z)
      CLEAN_RESTORE="true";;
    h | *)
      print_help
      exit 0;;
  esac
done

# Init
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"
[[ ! -z "$CONTAINER_NAME" ]] && CONTAINER_ARG="--container=$CONTAINER_NAME"
[[ ! -z "$DB_NAME" ]] && DB_NAME_ARG="-d $DB_NAME"

if [[ "$TARGET" == svc/* || "$TARGET" == service/* ]]; then
  SERVICE_NAME="${TARGET#*/}"
  POD_NAME=$(getPodFromService "$SERVICE_NAME")
  if [[ -z "$POD_NAME" ]]; then
    echo "No pods found for service : $SERVICE_NAME"
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
  > EXPORT_DIR: $(([ ${MODE} = 'dump' ] || [ ${MODE} = 'dump_forward' ]) && echo \"${EXPORT_DIR}\" || echo '-')
  > DUMP_FILE: $(([ ${MODE} = 'restore' ] || [ ${MODE} = 'restore_forward' ]) && echo \"${DUMP_FILE}\" || echo '-')
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > DB_PASS: $(if [ -n $DB_PASS ]; then printf "%*s" $(( ${#DB_PASS} - 3 )) "" | tr " " "*"; echo ${DB_PASS: -3}; else echo ''; fi)
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
  > CLEAN_RESTORE: $(([ ${MODE} = 'restore' ] || [ ${MODE} = 'restore_forward' ]) && echo \"${CLEAN_RESTORE}\" || echo '-')
"

# Options validation
if [ -z "$MODE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: mode (flag -m)".
  exit 1
elif [ -z "$TARGET" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: target pod or service (flag -t)".
  exit 1
elif [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ] && [ -z "$DB_NAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: database name (flag -d)".
  exit 1
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ] && [ -z "$DUMP_FILE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: dump file (flag -f)".
  exit 1
fi

# Check container fs permissions to store the dump file
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

# Dump database
if [ "$MODE" = "dump" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump database.\n\n"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "pg_dump -Fc -d $(getPgUri \"${DB_NAME}\") > ${DUMP_PATH}/${DUMP_FILENAME}"

  # Copy dump locally
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy dump file locally (path: '${DESTINATION_DUMP}').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILENAME} "${DESTINATION_DUMP}" ${CONTAINER_ARG}

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  [ ! -d "$EXPORT_DIR" ] && mkdir -p $EXPORT_DIR

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.dump"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump database locally (path: '${DESTINATION_DUMP}').\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5432:5432 &
  sleep 1
  pg_dump -Fc -d $(getPgUri \"${DB_NAME}\") ${DB_NAME_ARG} > ${DESTINATION_DUMP}

  kill %1

# Restore database
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename ${DUMP_FILE})"
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy local dump file into container (path: '$DUMP_PATH/$DUMP_FILE_BASENAME').\n\n"
  kubectl ${NAMESPACE_ARG} cp ${DUMP_FILE} ${POD_NAME}:${DUMP_PATH:1}/${DUMP_FILE_BASENAME} ${CONTAINER_ARG}

  # Restore database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore database.\n\n"
  if [ "$CLEAN_RESTORE" = "true" ]; then
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "psql -d $(getPgUri 'postgres') -c 'SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '\''"${DB_NAME}"'\'';'"
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "psql -d $(getPgUri 'postgres') -c 'DROP DATABASE IF EXISTS \"${DB_NAME}\";'"
    kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "psql -d $(getPgUri 'postgres') -c 'CREATE DATABASE \"${DB_NAME}\";'"
  fi
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "pg_restore -Fc -d $(getPgUri \"${DB_NAME}\") ${DUMP_PATH}/${DUMP_FILE_BASENAME}"
  kubectl ${NAMESPACE_ARG} exec ${POD_NAME} ${CONTAINER_ARG} -- bash -c "psql -d $(getPgUri 'postgres') -c 'ALTER DATABASE \"${DB_NAME}\" OWNER TO \"${DB_OWNER}\";'"

elif [ "$MODE" = "restore_forward" ]; then
  # Restore database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore database.\n\n"
  set +e
  kubectl ${NAMESPACE_ARG} port-forward ${POD_NAME} 5432:5432 &
  sleep 1
  if [ "$CLEAN_RESTORE" = "true" ]; then
    psql -d $(getPgUri 'postgres') -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '${DB_NAME}';"
    psql -d $(getPgUri 'postgres') -c "DROP DATABASE IF EXISTS \"${DB_NAME}\";"
    psql -d $(getPgUri 'postgres') -c "CREATE DATABASE \"${DB_NAME}\";"
  fi
  pg_restore -Fc -d $(getPgUri \"${DB_NAME}\") ${DUMP_FILE}
  psql -d $(getPgUri 'postgres') -c "ALTER DATABASE \"${DB_NAME}\" OWNER TO \"${DB_OWNER}\";"

  kill %1
fi

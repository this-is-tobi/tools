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
DB_USER="root"
DB_NAME=""
DB_PASS="${MYSQL_PWD:-}"
EXPORT_DIR="./backups"
DATE_TIME=$(date +"%Y%m%dT%H%M")
CLEAN_RESTORE="false"
DUMP_PATH=""
DUMP_FILE=""
MODE=""
TARGET=""
NAMESPACE_ARG=""
CONTAINER_ARG=""
POD_NAME=""
SERVICE_NAME=""
DB_PORT="3306"
LOCAL_PORT=""
PF_PID=""
PF_LOG=""
LOCAL_TMP_PATHS=()
POD_TMP_PATHS=()
PATHS=(
  /tmp
  /var/tmp
  /var/lib/mysql
  /bitnami/mariadb/data
)

# Script helper
TEXT_HELPER="
This script aims to perform a dump on a kubernetes mariadb pod and copy locally the dump file, or the opposite, restore a local dump file to a mariadb pod.

Available flags:
  -c    Name of the pod's container.
  -d    Name of the mariadb database.
  -f    Local dump file to restore (only needed with restore mode).
  -m    Mode to run. Available modes are:
          dump              - Dump the database locally.
          dump_forward      - Dump the database locally with port forward.
          restore           - Restore local dump into pod.
          restore_forward   - Restore local dump with port forward.
  -n    Kubernetes namespace target where the database pod is running.
        Default: the namespace of the current kubectl context.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'.
  -p    Password of the database user that will run the dump / restore command.
        Prefer the MYSQL_PWD environment variable: a -p value shows in the local process list.
  -t    Target name of the pod or service to run the dump / restore.
  -u    Database user used to dump / restore the database.
        Default: '$DB_USER'.
  -z    Drop the database if exists and re-create it before restore.
  -h    Print script help.

The password never reaches a command line: it is sent to the pod on stdin, or exported as
MYSQL_PWD for the local client in the *_forward modes. Those modes forward a random free
local port, so a mariadb server running on this machine is never touched.

Example:
  MYSQL_PWD='mypassword' ./backup-kube-mariadb.sh \\
    -m 'dump' \\
    -t 'my-mariadb-pod' \\
    -d 'mydatabase' \\
    -u 'myuser' \\
    -o './backups'

  MYSQL_PWD='mypassword' ./backup-kube-mariadb.sh \\
    -m 'restore' \\
    -t 'my-mariadb-pod' \\
    -f './backups/20240101T1200-mydatabase.sql' \\
    -d 'mydatabase' \\
    -u 'root' \\
    -z
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
    podExec rm -rf "${POD_TMP_PATHS[@]}" >/dev/null 2>&1 || true
  fi
  exit "$STATUS"
}

podExec () {
  kubectl ${NAMESPACE_ARG} exec "$POD_NAME" ${CONTAINER_ARG} -- "$@"
}

# Runs a shell snippet in the database container with the password exported as MYSQL_PWD. The
# password travels on stdin so it never shows in a process list or in the Kubernetes API audit
# log, and values reach the snippet as positional parameters instead of being spliced into it.
podMariadb () {
  local SCRIPT="$1"
  shift
  printf '%s' "$DB_PASS" | kubectl ${NAMESPACE_ARG} exec -i "$POD_NAME" ${CONTAINER_ARG} -- \
    sh -c 'pw=$(cat); if [ -n "$pw" ]; then MYSQL_PWD=$pw; export MYSQL_PWD; fi; '"$SCRIPT" sh "$@"
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

# Forwards a random free local port to the pod and waits for the tunnel to listen. A fixed local
# port would fail when a mariadb server already runs here, and the client would then connect to
# that local server instead of the pod.
startPortForward () {
  local TRIES=0
  PF_LOG="$(mktemp)"
  kubectl ${NAMESPACE_ARG} port-forward --address 127.0.0.1 "pod/${POD_NAME}" ":${DB_PORT}" > "$PF_LOG" 2>&1 &
  PF_PID=$!
  while true; do
    LOCAL_PORT="$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9][0-9]*\) .*/\1/p' "$PF_LOG" | head -n 1)"
    [ -n "$LOCAL_PORT" ] && break
    if ! kill -0 "$PF_PID" 2>/dev/null || [ "$TRIES" -ge 30 ]; then
      cat "$PF_LOG" >&2
      error "Port forward to pod '${POD_NAME}' (port ${DB_PORT}) did not start."
      exit 1
    fi
    TRIES=$((TRIES + 1))
    sleep 1
  done
  printf "Forwarding 127.0.0.1:%s to pod '%s' port %s.\n" "$LOCAL_PORT" "$POD_NAME" "$DB_PORT"
  if [ -n "$DB_PASS" ]; then
    export MYSQL_PWD="$DB_PASS"
  fi
}

checkDiskSpace () {
  local PATH_TO_CHECK="$1"
  local MIN_SPACE_MB=1024  # 1GB minimum for database dumps

  # Get available space in MB (-P = POSIX format, prevents line-wrapping for long device names)
  AVAILABLE_SPACE=$(podExec df -Pk "$PATH_TO_CHECK" | tail -1 | awk '{print int($4/1024)}')

  if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_MB" ]; then
    printf "\n${COLOR_YELLOW}Warning.${COLOR_OFF} Low disk space on ${PATH_TO_CHECK}: ${AVAILABLE_SPACE}MB available (minimum recommended: ${MIN_SPACE_MB}MB).\n"
    printf "The dump might fail if the database is too large.\n\n"
    printf "${COLOR_BLUE}Tip:${COLOR_OFF} Consider using 'dump_forward' mode instead, which dumps directly to your local machine\n"
    printf "without requiring space in the container. Example:\n"
    printf "  $0 -m dump_forward -t ${TARGET} -d ${DB_NAME} -u ${DB_USER} -o ${EXPORT_DIR}\n\n"
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

IS_DUMP="false"
IS_RESTORE="false"
if [ "$MODE" = "dump" ] || [ "$MODE" = "dump_forward" ]; then
  IS_DUMP="true"
elif [ "$MODE" = "restore" ] || [ "$MODE" = "restore_forward" ]; then
  IS_RESTORE="true"
fi

# Options validation
if [ -z "$MODE" ]; then
  error "Argument missing: mode (flag -m)."
  exit 1
elif [ "$IS_DUMP" = "false" ] && [ "$IS_RESTORE" = "false" ]; then
  error "Unknown mode '$MODE' (flag -m)."
  exit 1
elif [ -z "$TARGET" ]; then
  error "Argument missing: target pod or service (flag -t)."
  exit 1
elif [ "$IS_DUMP" = "true" ] && [ -z "$DB_NAME" ]; then
  error "Argument missing: database name (flag -d)."
  exit 1
elif [ "$IS_RESTORE" = "true" ] && [ -z "$DUMP_FILE" ]; then
  error "Argument missing: dump file (flag -f)."
  exit 1
elif [ "$IS_RESTORE" = "true" ] && [ ! -f "$DUMP_FILE" ]; then
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
  > EXPORT_DIR: $([ "$IS_DUMP" = "true" ] && echo "${EXPORT_DIR}" || echo '-')
  > DUMP_FILE: $([ "$IS_RESTORE" = "true" ] && echo "${DUMP_FILE}" || echo '-')
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > DB_PASS: $([ -n "$DB_PASS" ] && echo 'set' || echo 'not set')
  > NAMESPACE: ${NAMESPACE}
  > TARGET: ${TARGET}
  > POD_NAME: ${POD_NAME}
  > CONTAINER_NAME: ${CONTAINER_NAME}
  > CLEAN_RESTORE: $([ "$IS_RESTORE" = "true" ] && echo "${CLEAN_RESTORE}" || echo '-')
"

# Check container fs permissions to store the dump file
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

# Statements used with -z, the database name quoted as an identifier
BT='`'
DB_NAME_IDENT="${BT}${DB_NAME//$BT/$BT$BT}${BT}"
SQL_DROP="DROP DATABASE IF EXISTS ${DB_NAME_IDENT};"
SQL_CREATE="CREATE DATABASE ${DB_NAME_IDENT};"

# Dump database
if [ "$MODE" = "dump" ]; then
  # Check available disk space in container
  checkDiskSpace "$DUMP_PATH"

  # Create output directory
  mkdir -p "$EXPORT_DIR"

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.sql"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"
  POD_DUMP="${DUMP_PATH}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump database.\n\n"
  POD_TMP_PATHS=("$POD_DUMP")
  podMariadb 'exec mariadb-dump -u "$1" --single-transaction --routines --triggers --result-file="$3" "$2"' \
    "$DB_USER" "$DB_NAME" "$POD_DUMP"
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Database dump ended successfully.\n\n"

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

elif [ "$MODE" = "dump_forward" ]; then
  # Create output directory
  mkdir -p "$EXPORT_DIR"

  # Set paths variables
  DUMP_FILENAME="${DATE_TIME}-${DB_NAME}.sql"
  DESTINATION_DUMP="${EXPORT_DIR}/${DUMP_FILENAME}"

  # Dump database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Dump database locally (path: '${DESTINATION_DUMP}').\n\n"
  startPortForward
  LOCAL_TMP_PATHS=("${DESTINATION_DUMP}.partial")
  mariadb-dump -h 127.0.0.1 -P "$LOCAL_PORT" -u "$DB_USER" --single-transaction --routines --triggers \
    --result-file="${DESTINATION_DUMP}.partial" "$DB_NAME"
  mv "${DESTINATION_DUMP}.partial" "$DESTINATION_DUMP"
  LOCAL_TMP_PATHS=()

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Database dump ended successfully.\n\n"

# Restore database
elif [ "$MODE" = "restore" ]; then
  # Copy local dump into pod
  DUMP_FILE_BASENAME="$(basename "$DUMP_FILE")"
  POD_DUMP="${DUMP_PATH}/${DUMP_FILE_BASENAME}"
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Copy local dump file into container (path: '$POD_DUMP').\n\n"
  POD_TMP_PATHS=("$POD_DUMP")
  kubectl ${NAMESPACE_ARG} cp "$DUMP_FILE" "${POD_NAME}:${POD_DUMP}" ${CONTAINER_ARG}

  # Restore database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore database.\n\n"
  if [ "$CLEAN_RESTORE" = "true" ]; then
    podMariadb 'exec mariadb -u "$1" -e "$2"' "$DB_USER" "$SQL_DROP"
    podMariadb 'exec mariadb -u "$1" -e "$2"' "$DB_USER" "$SQL_CREATE"
  fi
  podMariadb 'exec mariadb -u "$1" "$2" < "$3"' "$DB_USER" "$DB_NAME" "$POD_DUMP"

  podExec rm -f "$POD_DUMP"
  POD_TMP_PATHS=()

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Database restore ended successfully.\n\n"

elif [ "$MODE" = "restore_forward" ]; then
  # Restore database
  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Restore database.\n\n"
  startPortForward
  if [ "$CLEAN_RESTORE" = "true" ]; then
    mariadb -h 127.0.0.1 -P "$LOCAL_PORT" -u "$DB_USER" -e "$SQL_DROP"
    mariadb -h 127.0.0.1 -P "$LOCAL_PORT" -u "$DB_USER" -e "$SQL_CREATE"
  fi
  mariadb -h 127.0.0.1 -P "$LOCAL_PORT" -u "$DB_USER" "$DB_NAME" < "$DUMP_FILE"

  printf "\n\n${COLOR_RED}[Dump wrapper].${COLOR_OFF} Database restore ended successfully.\n\n"
fi

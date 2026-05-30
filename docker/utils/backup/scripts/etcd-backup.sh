#!/bin/bash

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Trap errors
trap 'error "Backup failed at line $LINENO"' ERR

# Validate required environment variables
validate_required_vars \
  "ETCD_ENDPOINTS" \
  "S3_ENDPOINT" \
  "S3_ACCESS_KEY" \
  "S3_SECRET_KEY" \
  "S3_BUCKET_NAME"

DATE_TIME=$(date +"%Y%m%dT%H%M")

log "Starting etcd backup"
log "Settings:"
printf "  > ETCD_ENDPOINTS: ${ETCD_ENDPOINTS}\n"
printf "  > ETCD_CACERT: ${ETCD_CACERT}\n"
printf "  > ETCD_CERT: ${ETCD_CERT}\n"
printf "  > ETCD_KEY: ${ETCD_KEY}\n"
printf "  > ETCD_INSECURE_SKIP_TLS_VERIFY: ${ETCD_INSECURE_SKIP_TLS_VERIFY}\n"
printf "  > S3_ENDPOINT: ${S3_ENDPOINT}\n"
printf "  > S3_ACCESS_KEY: $(obfuscate "$S3_ACCESS_KEY")\n"
printf "  > S3_SECRET_KEY: $(obfuscate "$S3_SECRET_KEY")\n"
printf "  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}\n"
printf "  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}\n"
printf "  > S3_PATH_STYLE: ${S3_PATH_STYLE}\n"
printf "  > RETENTION: ${RETENTION}\n"
printf "  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone remote
configure_rclone_remote "backup_host" "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" "$S3_PATH_STYLE"


# Build optional TLS arguments
ETCD_TLS_ARGS=""
[ -n "${ETCD_CACERT}" ] && ETCD_TLS_ARGS="${ETCD_TLS_ARGS} --cacert=${ETCD_CACERT}"
[ -n "${ETCD_CERT}" ]   && ETCD_TLS_ARGS="${ETCD_TLS_ARGS} --cert=${ETCD_CERT}"
[ -n "${ETCD_KEY}" ]    && ETCD_TLS_ARGS="${ETCD_TLS_ARGS} --key=${ETCD_KEY}"
[ "${ETCD_INSECURE_SKIP_TLS_VERIFY}" = "true" ] && ETCD_TLS_ARGS="${ETCD_TLS_ARGS} --insecure-skip-tls-verify"


# Start snapshot and upload to s3
log "Creating etcd snapshot and uploading to S3"

SNAPSHOT_FILE="${DATE_TIME}-etcd.snapshot"
BACKUP_PATH="backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${SNAPSHOT_FILE}"

ETCDCTL_API=3 etcdctl snapshot save \
  --endpoints="${ETCD_ENDPOINTS}" \
  ${ETCD_TLS_ARGS} \
  ./${SNAPSHOT_FILE} \
  && rclone copyto --stats-one-line-date ${RCLONE_EXTRA_ARGS} ./${SNAPSHOT_FILE} "${BACKUP_PATH}" \
  && rm ./${SNAPSHOT_FILE}

log "Backup completed: ${BACKUP_PATH}"


# Delete backups older than retention period
cleanup_old_backups "backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/" "$RETENTION" "$RCLONE_EXTRA_ARGS"

log "Backup process finished successfully"

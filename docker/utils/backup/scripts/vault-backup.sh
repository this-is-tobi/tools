#!/bin/bash

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Trap errors
trap 'error "Backup failed at line $LINENO"' ERR

# Validate required environment variables
validate_required_vars \
  "VAULT_ADDR" \
  "VAULT_TOKEN" \
  "S3_ENDPOINT" \
  "S3_ACCESS_KEY" \
  "S3_SECRET_KEY" \
  "S3_BUCKET_NAME"

DATE_TIME=$(date +"%Y%m%dT%H%M")

log "Starting Vault backup"
log "Settings:"
printf "  > VAULT_ADDR: ${VAULT_ADDR}\n"
printf "  > VAULT_TOKEN: $(obfuscate "$VAULT_TOKEN")\n"
printf "  > VAULT_EXTRA_ARGS: ${VAULT_EXTRA_ARGS}\n"
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


# Start dump and stream to s3
log "Creating Vault snapshot and uploading to S3"

BACKUP_PATH="backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-vault.snap"

echo "${VAULT_TOKEN}" | vault login -address=${VAULT_ADDR} -non-interactive ${VAULT_EXTRA_ARGS} - \
  && vault operator raft snapshot save -address=${VAULT_ADDR} ${VAULT_EXTRA_ARGS} ./${DATE_TIME}-vault.snap \
  && rclone copyto --stats-one-line-date ${RCLONE_EXTRA_ARGS} ./${DATE_TIME}-vault.snap "${BACKUP_PATH}" \
  && rm ./${DATE_TIME}-vault.snap

log "Backup completed: ${BACKUP_PATH}"


# Delete backups older than retention period
cleanup_old_backups "backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/" "$RETENTION" "$RCLONE_EXTRA_ARGS"

log "Backup process finished successfully"

#!/bin/bash

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Trap errors
trap 'error "Backup failed at line $LINENO"' ERR

# Validate required environment variables
validate_required_vars \
  "DB_HOST" \
  "DB_PORT" \
  "DB_NAME" \
  "DB_USER" \
  "DB_PASS" \
  "S3_ENDPOINT" \
  "S3_ACCESS_KEY" \
  "S3_SECRET_KEY" \
  "S3_BUCKET_NAME"

# Validate DB_PORT is numeric
validate_port "DB_PORT" "$DB_PORT"

DATE_TIME=$(date +"%Y%m%dT%H%M")

log "Starting PostgreSQL backup"
printf "Settings:
  > DB_HOST: ${DB_HOST}
  > DB_PORT: ${DB_PORT}
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_ACCESS_KEY: ${S3_ACCESS_KEY}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > S3_PATH_STYLE: ${S3_PATH_STYLE}
  > RETENTION: ${RETENTION}
  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone remote
configure_rclone_remote "backup_host" "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" "$S3_PATH_STYLE"


# Start dump and stream to s3
log "Starting database dump and upload to S3"

BACKUP_PATH="backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-${DB_NAME}.dump"

PGPASSWORD="${DB_PASS}" pg_dump -Fc -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" "${DB_NAME}" \
  | rclone rcat ${RCLONE_EXTRA_ARGS} "${BACKUP_PATH}"

log "Backup completed: ${BACKUP_PATH}"


# Delete backups older than retention period
cleanup_old_backups "backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/" "$RETENTION" "$RCLONE_EXTRA_ARGS"

log "Backup process finished successfully"

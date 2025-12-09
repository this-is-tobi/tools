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

log "Starting MariaDB backup"
log "Settings:"
printf "  > DB_HOST: ${DB_HOST}\n"
printf "  > DB_PORT: ${DB_PORT}\n"
printf "  > DB_NAME: ${DB_NAME}\n"
printf "  > DB_USER: ${DB_USER}\n"
printf "  > DB_PASS: $(obfuscate "$DB_PASS")\n"
printf "  > S3_ENDPOINT: ${S3_ENDPOINT}\n"
printf "  > S3_ACCESS_KEY: $(obfuscate "$S3_ACCESS_KEY")\n"
printf "  > S3_SECRET_KEY: $(obfuscate "$S3_SECRET_KEY")\n"
printf "  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}\n"
printf "  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}\n"
printf "  > S3_PATH_STYLE: ${S3_PATH_STYLE}\n"
printf "  > DB_DUMP_ARGS: ${DB_DUMP_ARGS}\n"
printf "  > RETENTION: ${RETENTION}\n"
printf "  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone remote
configure_rclone_remote "backup_host" "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" "$S3_PATH_STYLE"


# Start dump and stream to s3
log "Starting database dump and upload to S3"

BACKUP_PATH="backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-${DB_NAME}.sql"

# Default dump arguments if not specified
DB_DUMP_ARGS="${DB_DUMP_ARGS:---single-transaction --routines --triggers}"

mariadb-dump -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" ${DB_DUMP_ARGS} "${DB_NAME}" \
  | rclone rcat --stats-one-line-date ${RCLONE_EXTRA_ARGS} "${BACKUP_PATH}"

log "Backup completed: ${BACKUP_PATH}"


# Delete backups older than retention period
cleanup_old_backups "backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/" "$RETENTION" "$RCLONE_EXTRA_ARGS"

log "Backup process finished successfully"

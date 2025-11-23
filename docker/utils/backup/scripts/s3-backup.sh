#!/bin/bash

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Trap errors
trap 'error "Backup failed at line $LINENO"' ERR

# Validate required environment variables
validate_required_vars \
  "SOURCE_S3_ENDPOINT" \
  "SOURCE_S3_ACCESS_KEY" \
  "SOURCE_S3_SECRET_KEY" \
  "SOURCE_S3_BUCKET_NAME" \
  "S3_ENDPOINT" \
  "S3_ACCESS_KEY" \
  "S3_SECRET_KEY" \
  "S3_BUCKET_NAME"

log "Starting S3 bucket sync"
log "Settings:"
printf "  > SOURCE_S3_ENDPOINT: ${SOURCE_S3_ENDPOINT}\n"
printf "  > SOURCE_S3_ACCESS_KEY: $(obfuscate "$SOURCE_S3_ACCESS_KEY")\n"
printf "  > SOURCE_S3_SECRET_KEY: $(obfuscate "$SOURCE_S3_SECRET_KEY")\n"
printf "  > SOURCE_S3_BUCKET_NAME: ${SOURCE_S3_BUCKET_NAME}\n"
printf "  > SOURCE_S3_BUCKET_PREFIX: ${SOURCE_S3_BUCKET_PREFIX}\n"
printf "  > S3_ENDPOINT: ${S3_ENDPOINT}\n"
printf "  > S3_ACCESS_KEY: $(obfuscate "$S3_ACCESS_KEY")\n"
printf "  > S3_SECRET_KEY: $(obfuscate "$S3_SECRET_KEY")\n"
printf "  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}\n"
printf "  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}\n"
printf "  > S3_PATH_STYLE: ${S3_PATH_STYLE}\n"
printf "  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone for source and target S3
log "Configuring rclone remotes"

# Source remote configuration
configure_rclone_remote "source_host" "$SOURCE_S3_ENDPOINT" "$SOURCE_S3_ACCESS_KEY" "$SOURCE_S3_SECRET_KEY" "$S3_PATH_STYLE"

# Target remote configuration
configure_rclone_remote "target_host" "$S3_ENDPOINT" "$S3_ACCESS_KEY" "$S3_SECRET_KEY" "$S3_PATH_STYLE"


# Start s3 bucket backup
log "Starting S3 sync from ${SOURCE_S3_BUCKET_NAME} to ${S3_BUCKET_NAME}"

SOURCE_PATH="source_host:${SOURCE_S3_BUCKET_NAME%/}${SOURCE_S3_BUCKET_PREFIX:+/}${SOURCE_S3_BUCKET_PREFIX%/}"
TARGET_PATH="target_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}"

rclone sync --stats-one-line-date ${RCLONE_EXTRA_ARGS} \
  --checksum \
  --transfers 4 \
  --checkers 8 \
  "$SOURCE_PATH" \
  "$TARGET_PATH"

log "Backup completed: ${TARGET_PATH}"
log "Backup process finished successfully"

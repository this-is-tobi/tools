#!/bin/bash

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# Validate destination configuration
validate_destination

# Trap errors
trap 'error "Backup failed at line $LINENO"' ERR

# Validate required environment variables
validate_required_vars \
  "QDRANT_URL" \
  "QDRANT_COLLECTION"

DATE_TIME=$(date +"%Y%m%dT%H%M")

log "Starting Qdrant backup"
log "Settings:"
printf "  > QDRANT_URL: ${QDRANT_URL}\n"
printf "  > QDRANT_COLLECTION: ${QDRANT_COLLECTION}\n"
printf "  > QDRANT_API_KEY: $(obfuscate "$QDRANT_API_KEY")\n"
printf "  > S3_ENDPOINT: ${S3_ENDPOINT}\n"
printf "  > S3_ACCESS_KEY: $(obfuscate "$S3_ACCESS_KEY")\n"
printf "  > S3_SECRET_KEY: $(obfuscate "$S3_SECRET_KEY")\n"
printf "  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}\n"
printf "  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}\n"
printf "  > S3_PATH_STYLE: ${S3_PATH_STYLE}\n"
printf "  > LOCAL_PATH: ${LOCAL_PATH}\n"
printf "  > RETENTION: ${RETENTION}\n"
printf "  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure backup destination
configure_backup_destination


# Prepare auth header if API key is provided
AUTH_HEADER=""
if [ ! -z "${QDRANT_API_KEY}" ]; then
  AUTH_HEADER="-H api-key: ${QDRANT_API_KEY}"
fi


# Start backup
printf "\n\nStart backup\n\n"

if [ -z "${QDRANT_COLLECTION}" ] || [ "${QDRANT_COLLECTION}" = "all" ]; then
  # Full cluster snapshot
  log "Creating full cluster snapshot"
  
  SNAPSHOT=$(curl -s -X POST ${AUTH_HEADER} "${QDRANT_URL}/snapshots" | jq -r '.result.name')
  
  if [ -z "${SNAPSHOT}" ] || [ "${SNAPSHOT}" = "null" ]; then
    error "Failed to create snapshot"
    exit 1
  fi
  
  log "Snapshot created: ${SNAPSHOT}"
  log "Uploading to destination..."
  
  BACKUP_PATH="${DEST_BASE}/${DATE_TIME}-cluster.snapshot"
  
  curl -s ${AUTH_HEADER} "${QDRANT_URL}/snapshots/${SNAPSHOT}" \
    | rclone rcat --stats-one-line-date ${RCLONE_EXTRA_ARGS} "${BACKUP_PATH}"
  
  # Delete local snapshot from Qdrant
  curl -s -X DELETE ${AUTH_HEADER} "${QDRANT_URL}/snapshots/${SNAPSHOT}" > /dev/null
  
  log "Backup completed: ${BACKUP_PATH}"

else
  # Collection snapshot
  log "Creating snapshot for collection: ${QDRANT_COLLECTION}"
  
  SNAPSHOT=$(curl -s -X POST ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots" | jq -r '.result.name')
  
  if [ -z "${SNAPSHOT}" ] || [ "${SNAPSHOT}" = "null" ]; then
    error "Failed to create collection snapshot"
    exit 1
  fi
  
  log "Snapshot created: ${SNAPSHOT}"
  log "Streaming to destination..."
  
  BACKUP_PATH="${DEST_BASE}/${DATE_TIME}-${QDRANT_COLLECTION}.snapshot"
  
  curl -s ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots/${SNAPSHOT}" \
    | rclone rcat --stats-one-line-date ${RCLONE_EXTRA_ARGS} "${BACKUP_PATH}"
  
  # Delete snapshot from Qdrant server
  curl -s -X DELETE ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots/${SNAPSHOT}" > /dev/null
  
  log "Backup completed: ${BACKUP_PATH}"
fi


# Delete backups older than retention period
cleanup_old_backups "${DEST_BASE}/" "$RETENTION" "$RCLONE_EXTRA_ARGS"

log "Backup process finished successfully"

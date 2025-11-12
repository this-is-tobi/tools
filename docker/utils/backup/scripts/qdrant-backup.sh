#!/bin/bash

DATE_TIME=$(date +"%Y%m%dT%H%M")

printf "Settings:
  > QDRANT_URL: ${QDRANT_URL}
  > QDRANT_COLLECTION: ${QDRANT_COLLECTION}
  > QDRANT_API_KEY: ${QDRANT_API_KEY:+***}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_ACCESS_KEY: ${S3_ACCESS_KEY}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > S3_PATH_STYLE: ${S3_PATH_STYLE}
  > RETENTION: ${RETENTION}
  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone remote
printf "\n\nConfiguring rclone remote\n\n"

rclone config delete backup_host 2>/dev/null || true
rclone config create backup_host s3 \
  provider AWS \
  env_auth false \
  access_key_id "${S3_ACCESS_KEY}" \
  secret_access_key "${S3_SECRET_KEY}" \
  endpoint "${S3_ENDPOINT}" \
  $([ "${S3_PATH_STYLE}" = "true" ] && echo "force_path_style true")


# Prepare auth header if API key is provided
AUTH_HEADER=""
if [ ! -z "${QDRANT_API_KEY}" ]; then
  AUTH_HEADER="-H api-key: ${QDRANT_API_KEY}"
fi


# Start backup
printf "\n\nStart backup\n\n"

if [ -z "${QDRANT_COLLECTION}" ] || [ "${QDRANT_COLLECTION}" = "all" ]; then
  # Full cluster snapshot
  printf "Creating full cluster snapshot\n"
  
  SNAPSHOT=$(curl -s -X POST ${AUTH_HEADER} "${QDRANT_URL}/snapshots" | jq -r '.result.name')
  
  if [ -z "${SNAPSHOT}" ] || [ "${SNAPSHOT}" = "null" ]; then
    printf "ERROR: Failed to create snapshot\n"
    exit 1
  fi
  
  printf "Snapshot created: ${SNAPSHOT}\n"
  printf "Uploading to S3...\n"
  
  curl -s ${AUTH_HEADER} "${QDRANT_URL}/snapshots/${SNAPSHOT}" \
    | rclone rcat ${RCLONE_EXTRA_ARGS} backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-cluster.snapshot
  
  # Delete local snapshot from Qdrant
  curl -s -X DELETE ${AUTH_HEADER} "${QDRANT_URL}/snapshots/${SNAPSHOT}" > /dev/null

else
  # Collection snapshot
  printf "Creating snapshot for collection: ${QDRANT_COLLECTION}\n"
  
  SNAPSHOT=$(curl -s -X POST ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots" | jq -r '.result.name')
  
  if [ -z "${SNAPSHOT}" ] || [ "${SNAPSHOT}" = "null" ]; then
    printf "ERROR: Failed to create collection snapshot\n"
    exit 1
  fi
  
  printf "Snapshot created: ${SNAPSHOT}\n"
  printf "Uploading to S3...\n"
  
  curl -s ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots/${SNAPSHOT}" \
    | rclone rcat ${RCLONE_EXTRA_ARGS} backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-${QDRANT_COLLECTION}.snapshot
  
  # Delete local snapshot from Qdrant
  curl -s -X DELETE ${AUTH_HEADER} "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/snapshots/${SNAPSHOT}" > /dev/null
fi

printf "\n\nBackup finished\n\n"


# Delete backups older than
if [ ! -z "${RETENTION}" ]; then
  printf "\n\nDelete backups older than ${RETENTION} in '${S3_BUCKET_NAME}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}'\n\n"

  rclone delete ${RCLONE_EXTRA_ARGS} --min-age "${RETENTION}" backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/
fi

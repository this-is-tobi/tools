#!/bin/bash

printf "Settings:
  > SOURCE_S3_ENDPOINT: ${SOURCE_S3_ENDPOINT}
  > SOURCE_S3_ACCESS_KEY: ${SOURCE_S3_ACCESS_KEY}
  > SOURCE_S3_BUCKET_NAME: ${SOURCE_S3_BUCKET_NAME}
  > SOURCE_S3_BUCKET_PREFIX: ${SOURCE_S3_BUCKET_PREFIX}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_ACCESS_KEY: ${S3_ACCESS_KEY}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > S3_PATH_STYLE: ${S3_PATH_STYLE}
  > RCLONE_EXTRA_ARGS: ${RCLONE_EXTRA_ARGS}\n"


# Configure rclone for source and target S3
printf "\n\nConfiguring rclone remotes\n\n"

# Source remote configuration
rclone config delete source_host 2>/dev/null || true
rclone config create source_host s3 \
  provider AWS \
  env_auth false \
  access_key_id "${SOURCE_S3_ACCESS_KEY}" \
  secret_access_key "${SOURCE_S3_SECRET_KEY}" \
  endpoint "${SOURCE_S3_ENDPOINT}" \
  $([ "${S3_PATH_STYLE}" = "true" ] && echo "force_path_style true")

# Target remote configuration
rclone config delete target_host 2>/dev/null || true
rclone config create target_host s3 \
  provider AWS \
  env_auth false \
  access_key_id "${S3_ACCESS_KEY}" \
  secret_access_key "${S3_SECRET_KEY}" \
  endpoint "${S3_ENDPOINT}" \
  $([ "${S3_PATH_STYLE}" = "true" ] && echo "force_path_style true")


# Start s3 bucket backup
printf "\n\nStart backup\n\n"

rclone sync ${RCLONE_EXTRA_ARGS} \
  --checksum \
  --transfers 4 \
  --checkers 8 \
  --progress \
  source_host:${SOURCE_S3_BUCKET_NAME%/}${SOURCE_S3_BUCKET_PREFIX:+/}${SOURCE_S3_BUCKET_PREFIX%/} \
  target_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}

printf "\n\nBackup finished\n\n"

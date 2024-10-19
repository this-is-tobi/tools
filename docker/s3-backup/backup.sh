#!/bin/bash

printf "Settings:
  > SOURCE_S3_ENDPOINT: ${SOURCE_S3_ENDPOINT}
  > SOURCE_S3_BUCKET_NAME: ${SOURCE_S3_BUCKET_NAME}
  > SOURCE_S3_BUCKET_PREFIX: ${SOURCE_S3_BUCKET_PREFIX}
  > TARGET_S3_ENDPOINT: ${TARGET_S3_ENDPOINT}
  > TARGET_S3_BUCKET_NAME: ${TARGET_S3_BUCKET_NAME}
  > TARGET_S3_BUCKET_PREFIX: ${TARGET_S3_BUCKET_PREFIX}
  > MC_EXTRA_ARGS: ${MC_EXTRA_ARGS}\n"


# Add s3 host to minio-cli
printf "\n\nAdd minio alias\n\n"

mc alias set source_host "${SOURCE_S3_ENDPOINT}" "${SOURCE_S3_ACCESS_KEY}" "${SOURCE_S3_SECRET_KEY}"
mc alias set target_host "${TARGET_S3_ENDPOINT}" "${TARGET_S3_ACCESS_KEY}" "${TARGET_S3_SECRET_KEY}"

# Start s3 bucket backup
printf "\n\nStart backup\n\n"

mc cp ${MC_EXTRA_ARGS} \
  --recursive \
  --preserve \
  --md5 \
  source_host/${SOURCE_S3_BUCKET_NAME%/}${SOURCE_S3_BUCKET_PREFIX:+/}${SOURCE_S3_BUCKET_PREFIX%/} \
  target_host/${TARGET_S3_BUCKET_NAME%/}${TARGET_S3_BUCKET_PREFIX:+/}${TARGET_S3_BUCKET_PREFIX%/}

printf "\n\nBackup finished\n\n"

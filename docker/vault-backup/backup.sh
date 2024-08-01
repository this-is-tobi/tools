#!/bin/bash

DATE_TIME=$(date +"%Y%m%dT%H%M")

printf "Settings:
  > VAULT_ADDR: ${VAULT_ADDR}
  > VAULT_EXTRA_ARGS: ${VAULT_EXTRA_ARGS}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > RETENTION: ${RETENTION}
  > MC_EXTRA_ARGS: ${MC_EXTRA_ARGS}\n"


# Add s3 host to minio-cli
printf "\n\nAdd minio alias\n\n"

mc ${MC_EXTRA_ARGS} alias set backup_host "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"

# Start dump and stream to s3
printf "\n\nStart backup\n\n"

echo "${VAULT_TOKEN}" | vault login -address=${VAULT_ADDR} -non-interactive ${VAULT_EXTRA_ARGS} - \
  && vault operator raft snapshot save -address=${VAULT_ADDR} ${VAULT_EXTRA_ARGS} ./${DATE_TIME}-vault.snap \
  && mc ${MC_EXTRA_ARGS} cp ./${DATE_TIME}-vault.snap backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-vault.snap

printf "\n\nBackup finished\n\n"

# Delete backups older than
if [ ! -z "${RETENTION}" ]; then
  printf "\n\nDelete backups older than ${RETENTION} in '${S3_BUCKET_NAME}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}'\n\n"

  mc ${MC_EXTRA_ARGS} rm --recursive --force --older-than "${RETENTION}" backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}
fi

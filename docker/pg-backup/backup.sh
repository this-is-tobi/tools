#!/bin/bash

printf "Settings:
  > DB_HOST: ${DB_HOST}
  > DB_PORT: ${DB_PORT}
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > RETENTION_DAYS: ${RETENTION_DAYS}\n"


# Add s3 host to minio-cli
printf "\nAdd minio alias\n"

mc alias set backup_host "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"

# Start dump and stream to s3
printf "\nStart backup\n"

PGPASSWORD="${DB_PASS}" pg_dump -Fc -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" "${DB_NAME}" \
  | mc pipe backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/$(date +"%Y-%m-%dT%H-%M")-${DB_NAME}.dump

printf "\nBackup finished\n"

# Delete backups older than
re='^[0-9]+$'
if [[ ! -z "${RETENTION_DAYS}" ]] && [[ "${RETENTION_DAYS}" =~ $re ]]; then
  printf "\nDelete backups older than ${RETENTION_DAYS}days in '${S3_BUCKET_NAME}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}'\n"

  mc rm --recursive --force --older-than "${RETENTION_DAYS}d" backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}
fi

#!/bin/bash

DATE_TIME=$(date +"%Y%m%dT%H%M")

printf "Settings:
  > DB_HOST: ${DB_HOST}
  > DB_PORT: ${DB_PORT}
  > DB_NAME: ${DB_NAME}
  > DB_USER: ${DB_USER}
  > S3_ENDPOINT: ${S3_ENDPOINT}
  > S3_BUCKET_NAME: ${S3_BUCKET_NAME}
  > S3_BUCKET_PREFIX: ${S3_BUCKET_PREFIX}
  > S3_PATH_STYLE: ${S3_PATH_STYLE}
  > RETENTION: ${RETENTION}
  > MC_EXTRA_ARGS: ${MC_EXTRA_ARGS}\n"


# Add s3 host to minio-cli
printf "\n\nAdd minio alias\n\n"

if [ "${S3_PATH_STYLE}" = "false" ]; then
  mc ${MC_EXTRA_ARGS} alias set backup_host "$(echo ${S3_ENDPOINT} | sed -E 's|(https?://)([^.]+\.)(.+)|\1\3|')" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"
else
  mc ${MC_EXTRA_ARGS} alias set backup_host "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}"
fi


# Start dump and stream to s3
printf "\n\nStart backup\n\n"

PGPASSWORD="${DB_PASS}" pg_dump -Fc -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" "${DB_NAME}" \
  | mc ${MC_EXTRA_ARGS} pipe backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-${DB_NAME}.dump

printf "\n\nBackup finished\n\n"


# Delete backups older than
if [ ! -z "${RETENTION}" ]; then
  printf "\n\nDelete backups older than ${RETENTION} in '${S3_BUCKET_NAME}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}'\n\n"

  mc ${MC_EXTRA_ARGS} rm --recursive --force --older-than "${RETENTION}" backup_host/${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}
fi

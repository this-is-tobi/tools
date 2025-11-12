#!/bin/bash

DATE_TIME=$(date +"%Y%m%dT%H%M")

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
printf "\n\nConfiguring rclone remote\n\n"

rclone config delete backup_host 2>/dev/null || true
rclone config create backup_host s3 \
  provider AWS \
  env_auth false \
  access_key_id "${S3_ACCESS_KEY}" \
  secret_access_key "${S3_SECRET_KEY}" \
  endpoint "${S3_ENDPOINT}" \
  $([ "${S3_PATH_STYLE}" = "true" ] && echo "force_path_style true")


# Start dump and stream to s3
printf "\n\nStart backup\n\n"

PGPASSWORD="${DB_PASS}" pg_dump -Fc -U "${DB_USER}" -h "${DB_HOST}" -p "${DB_PORT}" "${DB_NAME}" \
  | rclone rcat ${RCLONE_EXTRA_ARGS} backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX%/}/${DATE_TIME}-${DB_NAME}.dump

printf "\n\nBackup finished\n\n"


# Delete backups older than
if [ ! -z "${RETENTION}" ]; then
  printf "\n\nDelete backups older than ${RETENTION} in '${S3_BUCKET_NAME}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}'\n\n"

  rclone delete ${RCLONE_EXTRA_ARGS} --min-age "${RETENTION}" backup_host:${S3_BUCKET_NAME%/}${S3_BUCKET_PREFIX:+/}${S3_BUCKET_PREFIX}/
fi

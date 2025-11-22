#!/bin/bash

set -e

# If arguments are provided, execute them
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Otherwise, show help/usage information
cat << EOF
╔═══════════════════════════════════════════════════════════════════╗
║                     Backup Utility Container                      ║
╚═══════════════════════════════════════════════════════════════════╝

Available backup scripts:
  • postgres-backup.sh  - Backup PostgreSQL database to S3
  • vault-backup.sh     - Backup HashiCorp Vault to S3
  • qdrant-backup.sh    - Backup Qdrant vector database to S3
  • s3-backup.sh        - Sync/backup between S3 buckets

Available tools:
  • rclone              - Cloud storage sync
  • vault               - HashiCorp Vault CLI
  • pg_dump/pg_restore  - PostgreSQL client tools
  • curl, jq, yq        - Data processing utilities

Usage examples:

  # Run a specific backup script
  docker run --rm -e VAR=value backup:latest bash ${HOME}/scripts/postgres-backup.sh

  # Run healthcheck
  docker run --rm backup:latest ${HOME}/scripts/healthcheck.sh

  # Interactive shell
  docker run --rm -it backup:latest bash

  # Use as Kubernetes CronJob
  kubectl apply -f cronjob.yaml

Environment variables required (varies by script):

  PostgreSQL backup:
    - DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
    - S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME
    - S3_BUCKET_PREFIX (optional), S3_PATH_STYLE (optional, true/false)
    - RETENTION (optional, e.g., 30d)
    - RCLONE_EXTRA_ARGS (optional)

  Vault backup:
    - VAULT_ADDR, VAULT_TOKEN
    - S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME
    - S3_BUCKET_PREFIX (optional), S3_PATH_STYLE (optional, true/false)
    - RETENTION (optional, e.g., 30d)
    - VAULT_EXTRA_ARGS (optional)
    - RCLONE_EXTRA_ARGS (optional)

  Qdrant backup:
    - QDRANT_URL, QDRANT_COLLECTION (or "all" for full cluster)
    - S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME
    - QDRANT_API_KEY (optional)
    - S3_BUCKET_PREFIX (optional), S3_PATH_STYLE (optional, true/false)
    - RETENTION (optional, e.g., 30d)
    - RCLONE_EXTRA_ARGS (optional)

  S3 sync:
    - SOURCE_S3_ENDPOINT, SOURCE_S3_ACCESS_KEY, SOURCE_S3_SECRET_KEY
    - SOURCE_S3_BUCKET_NAME
    - S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, S3_BUCKET_NAME
    - SOURCE_S3_BUCKET_PREFIX (optional)
    - S3_BUCKET_PREFIX (optional)
    - S3_PATH_STYLE (optional, true/false)
    - RCLONE_EXTRA_ARGS (optional)

For more information, check the scripts in ${HOME}/scripts/

EOF

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
    Required:
      - DB_HOST            Database host
      - DB_PORT            Database port (numeric, 1-65535)
      - DB_NAME            Database name
      - DB_USER            Database user
      - DB_PASS            Database password
      - S3_ENDPOINT        S3 endpoint URL
      - S3_ACCESS_KEY      S3 access key
      - S3_SECRET_KEY      S3 secret key
      - S3_BUCKET_NAME     S3 bucket name
    Optional:
      - S3_BUCKET_PREFIX   S3 prefix path (default: empty)
      - S3_PATH_STYLE      Force path-style URLs (true/false, default: false)
      - RETENTION          Retention period (e.g., 30d, 60d)
      - RCLONE_EXTRA_ARGS  Additional rclone arguments

  Vault backup:
    Required:
      - VAULT_ADDR         Vault server address
      - VAULT_TOKEN        Vault authentication token
      - S3_ENDPOINT        S3 endpoint URL
      - S3_ACCESS_KEY      S3 access key
      - S3_SECRET_KEY      S3 secret key
      - S3_BUCKET_NAME     S3 bucket name
    Optional:
      - S3_BUCKET_PREFIX   S3 prefix path (default: empty)
      - S3_PATH_STYLE      Force path-style URLs (true/false, default: false)
      - RETENTION          Retention period (e.g., 30d, 60d)
      - VAULT_EXTRA_ARGS   Additional vault arguments
      - RCLONE_EXTRA_ARGS  Additional rclone arguments

  Qdrant backup:
    Required:
      - QDRANT_URL         Qdrant server URL
      - QDRANT_COLLECTION  Collection name or "all" for full cluster
      - S3_ENDPOINT        S3 endpoint URL
      - S3_ACCESS_KEY      S3 access key
      - S3_SECRET_KEY      S3 secret key
      - S3_BUCKET_NAME     S3 bucket name
    Optional:
      - QDRANT_API_KEY     Qdrant API key for authentication
      - S3_BUCKET_PREFIX   S3 prefix path (default: empty)
      - S3_PATH_STYLE      Force path-style URLs (true/false, default: false)
      - RETENTION          Retention period (e.g., 30d, 60d)
      - RCLONE_EXTRA_ARGS  Additional rclone arguments

  S3 sync:
    Required:
      - SOURCE_S3_ENDPOINT      Source S3 endpoint URL
      - SOURCE_S3_ACCESS_KEY    Source S3 access key
      - SOURCE_S3_SECRET_KEY    Source S3 secret key
      - SOURCE_S3_BUCKET_NAME   Source S3 bucket name
      - S3_ENDPOINT             Target S3 endpoint URL
      - S3_ACCESS_KEY           Target S3 access key
      - S3_SECRET_KEY           Target S3 secret key
      - S3_BUCKET_NAME          Target S3 bucket name
    Optional:
      - SOURCE_S3_BUCKET_PREFIX Source S3 prefix path (default: empty)
      - S3_BUCKET_PREFIX        Target S3 prefix path (default: empty)
      - S3_PATH_STYLE           Force path-style URLs (true/false, default: false)
      - RCLONE_EXTRA_ARGS       Additional rclone arguments

For more information, check the scripts in ${HOME}/scripts/

EOF

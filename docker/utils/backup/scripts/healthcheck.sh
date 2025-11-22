#!/bin/bash

set -e

# Check all required binaries exist and are executable
echo "Checking required tools..."

command -v bash >/dev/null 2>&1 || { echo "ERROR: bash not found"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "ERROR: curl not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "ERROR: yq not found"; exit 1; }
command -v rclone >/dev/null 2>&1 || { echo "ERROR: rclone not found"; exit 1; }
command -v vault >/dev/null 2>&1 || { echo "ERROR: vault not found"; exit 1; }
command -v pg_dump >/dev/null 2>&1 || { echo "ERROR: pg_dump not found"; exit 1; }
command -v pg_restore >/dev/null 2>&1 || { echo "ERROR: pg_restore not found"; exit 1; }

echo "✓ All required tools found"

# Test that tools can run
echo "Testing tool execution..."

rclone version >/dev/null 2>&1 || { echo "ERROR: rclone execution failed"; exit 1; }
vault version >/dev/null 2>&1 || { echo "ERROR: vault execution failed"; exit 1; }
pg_dump --version >/dev/null 2>&1 || { echo "ERROR: pg_dump execution failed"; exit 1; }

echo "✓ All tools execute successfully"

# Check backup scripts exist
echo "Checking backup scripts..."

[ -f "${HOME}/scripts/postgres-backup.sh" ] || { echo "ERROR: postgres-backup.sh not found"; exit 1; }
[ -f "${HOME}/scripts/vault-backup.sh" ] || { echo "ERROR: vault-backup.sh not found"; exit 1; }
[ -f "${HOME}/scripts/qdrant-backup.sh" ] || { echo "ERROR: qdrant-backup.sh not found"; exit 1; }
[ -f "${HOME}/scripts/s3-backup.sh" ] || { echo "ERROR: s3-backup.sh not found"; exit 1; }

# Check scripts are executable
[ -x "${HOME}/scripts/postgres-backup.sh" ] || { echo "ERROR: postgres-backup.sh not executable"; exit 1; }
[ -x "${HOME}/scripts/vault-backup.sh" ] || { echo "ERROR: vault-backup.sh not executable"; exit 1; }
[ -x "${HOME}/scripts/qdrant-backup.sh" ] || { echo "ERROR: qdrant-backup.sh not executable"; exit 1; }
[ -x "${HOME}/scripts/s3-backup.sh" ] || { echo "ERROR: s3-backup.sh not executable"; exit 1; }

echo "✓ All backup scripts found and executable"

echo "✓ Healthcheck passed - backup image is ready"
exit 0

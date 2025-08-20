#!/bin/bash
set -euo pipefail

# Source common utilities
source /scripts/common.sh

log "Setting up Vault secrets for $SERVICE_NAME..."

# Vault configuration
export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_TOKEN="${VAULT_TOKEN}"

# Check if Vault is accessible
log "Checking Vault status..."
vault status || {
  error "Vault is not accessible or sealed"
  exit 1
}

# Create secrets based on service configuration
if [ -f "/config/vault-config.json" ]; then
  log "Processing Vault configuration for $SERVICE_NAME..."

  # Process each secret in the configuration
  jq -c '.secrets[]?' /config/vault-config.json | while read secret; do
    SECRET_PATH=$(echo "$secret" | jq -r '.path')
    SECRET_DATA=$(echo "$secret" | jq -r '.data')

    log "Creating/updating secret at: $SECRET_PATH"

    # Check if secret already exists
    if vault kv get -format=json "$SECRET_PATH" >/dev/null 2>&1; then
      log "Secret exists, merging with existing data..."
      # Merge with existing data
      EXISTING_DATA=$(vault kv get -format=json "$SECRET_PATH" | jq '.data.data')
      MERGED_DATA=$(echo "$EXISTING_DATA $SECRET_DATA" | jq -s '.[0] * .[1]')
      echo "$MERGED_DATA" | vault kv put "$SECRET_PATH" -
    else
      log "Creating new secret..."
      echo "$SECRET_DATA" | vault kv put "$SECRET_PATH" -
    fi

    success "Secret created/updated: $SECRET_PATH"
  done

  # Verify all secrets were created
  log "Verifying secrets for $SERVICE_NAME..."
  jq -r '.secrets[].path' /config/vault-config.json | while read path; do
    if vault kv get "$path" >/dev/null 2>&1; then
      success "Secret verified: $path"
    else
      error "Secret verification failed: $path"
      exit 1
    fi
  done
else
  warn "No Vault configuration found for $SERVICE_NAME"
fi

success "Vault secrets setup completed for $SERVICE_NAME"

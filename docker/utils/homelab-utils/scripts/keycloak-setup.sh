#!/bin/bash
set -euo pipefail

# Source common utilities
source /scripts/common.sh

log "Setting up Keycloak configuration for $SERVICE_NAME..."

# Wait for Keycloak to be ready
wait_for_http "${KEYCLOAK_URL}/realms/master/.well-known/openid_configuration"

# Get admin access token
log "Getting Keycloak admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_ADMIN_USERNAME}" \
  -d "password=${KEYCLOAK_ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  error "Failed to get admin token"
  exit 1
fi

# Process Keycloak configuration
if [ -f "/config/keycloak-config.json" ]; then
  # Create realm if specified
  if jq -e '.realm' /config/keycloak-config.json > /dev/null; then
    REALM_NAME=$(jq -r '.realm.realm' /config/keycloak-config.json)
    log "Creating/updating realm: $REALM_NAME"

    # Check if realm exists
    if ! curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" >/dev/null; then
      # Create realm
      curl -sf -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$(jq '.realm' /config/keycloak-config.json)"
      success "Realm $REALM_NAME created"
    else
      log "Realm $REALM_NAME already exists"
    fi
  fi

  # Create groups if specified
  if jq -e '.groups' /config/keycloak-config.json > /dev/null; then
    log "Creating groups..."
    jq -c '.groups[]?' /config/keycloak-config.json | while read group; do
      GROUP_NAME=$(echo "$group" | jq -r '.name')
      log "Creating group: $GROUP_NAME"
      curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/groups" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$group" || warn "Group $GROUP_NAME may already exist"
    done
  fi

  # Create client scopes if specified
  if jq -e '.clientScopes' /config/keycloak-config.json > /dev/null; then
    log "Creating client scopes..."
    jq -c '.clientScopes[]?' /config/keycloak-config.json | while read scope; do
      SCOPE_NAME=$(echo "$scope" | jq -r '.name')
      log "Creating client scope: $SCOPE_NAME"
      curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/client-scopes" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$scope" || warn "Client scope $SCOPE_NAME may already exist"
    done
  fi

  # Create clients if specified
  if jq -e '.clients' /config/keycloak-config.json > /dev/null; then
    log "Creating clients..."
    jq -c '.clients[]?' /config/keycloak-config.json | while read client; do
      CLIENT_ID=$(echo "$client" | jq -r '.clientId')
      log "Creating client: $CLIENT_ID"

      # Check if client exists
      EXISTING_CLIENT=$(curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" \
        "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id // empty')

      if [ -z "$EXISTING_CLIENT" ]; then
        # Create client
        curl -sf -X POST "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients" \
          -H "Authorization: Bearer $ADMIN_TOKEN" \
          -H "Content-Type: application/json" \
          -d "$client"
        success "Client $CLIENT_ID created"

        # Get client secret and store it
        sleep 2  # Wait for client to be created
        CLIENT_UUID=$(curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" \
          "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients?clientId=${CLIENT_ID}" | jq -r '.[0].id')

        if [ -n "$CLIENT_UUID" ] && [ "$CLIENT_UUID" != "null" ]; then
          CLIENT_SECRET=$(curl -sf -H "Authorization: Bearer $ADMIN_TOKEN" \
            "${KEYCLOAK_URL}/admin/realms/${KEYCLOAK_REALM}/clients/${CLIENT_UUID}/client-secret" | jq -r '.value')

          # Store client secret in Kubernetes secret
          kubectl create secret generic "${SERVICE_NAME}-keycloak-client" \
            --from-literal=client-secret="$CLIENT_SECRET" \
            --dry-run=client -o yaml | kubectl apply -f -
          success "Client secret stored for $SERVICE_NAME"
        fi
      else
        log "Client $CLIENT_ID already exists"
      fi
    done
  fi
else
  warn "No Keycloak configuration found for $SERVICE_NAME"
fi

success "Keycloak configuration completed for $SERVICE_NAME"

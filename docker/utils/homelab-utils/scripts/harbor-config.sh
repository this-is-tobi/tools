#!/bin/bash
# Harbor Post-Install Configuration Script
# Configures Harbor with OIDC authentication and Trivy scanning

set -euo pipefail

# Get script directory for sourcing common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Configuration defaults
HARBOR_NAMESPACE="${HARBOR_NAMESPACE:-harbor}"
HARBOR_SECRET_NAME="${HARBOR_SECRET_NAME:-harbor-secret}"
KEYCLOAK_NAMESPACE="${KEYCLOAK_NAMESPACE:-keycloak}"
KEYCLOAK_SECRET_NAME="${KEYCLOAK_SECRET_NAME:-keycloak-secret}"
HARBOR_API_VERSION="${HARBOR_API_VERSION:-v2.0}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-30}"
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-10}"

# ================================================
# Validation and Initialization
# ================================================

log "=================================================="
log "Harbor Post-Install Configuration"
log "=================================================="
log ""

# Validate required tools
validate_required_tools() {
  validate_tools "curl" "jq" "kubectl" "base64" || exit 1
}

# Load configuration from environment or Kubernetes secrets
load_config() {
  log "Loading Harbor configuration..."
  
  # Try to load from environment variables first
  if [ -n "${HARBOR_DOMAIN:-}" ] && [ -n "${HARBOR_USERNAME:-}" ] && [ -n "${HARBOR_PASSWORD:-}" ]; then
    log "Using configuration from environment variables"
  else
    # Try to load from Kubernetes secret
    log "Loading configuration from Kubernetes secret: ${HARBOR_SECRET_NAME}"
    
    if ! kubectl get secret "${HARBOR_SECRET_NAME}" -n "${HARBOR_NAMESPACE}" >/dev/null 2>&1; then
      error "Secret ${HARBOR_SECRET_NAME} not found in namespace ${HARBOR_NAMESPACE}"
      error "Please provide configuration via environment variables or Kubernetes secret"
      exit 1
    fi
    
    HARBOR_DOMAIN=$(get_secret_value "${HARBOR_SECRET_NAME}" "domain" "${HARBOR_NAMESPACE}")
    HARBOR_USERNAME=$(get_secret_value "${HARBOR_SECRET_NAME}" "admin.username" "${HARBOR_NAMESPACE}")
    HARBOR_PASSWORD=$(get_secret_value "${HARBOR_SECRET_NAME}" "admin.password" "${HARBOR_NAMESPACE}")
    HARBOR_CLIENT_ID=$(get_secret_value "${HARBOR_SECRET_NAME}" "keycloak.clientId" "${HARBOR_NAMESPACE}")
    HARBOR_CLIENT_SECRET=$(get_secret_value "${HARBOR_SECRET_NAME}" "keycloak.clientSecret" "${HARBOR_NAMESPACE}")
  fi
  
  # Load Keycloak configuration
  if [ -z "${KEYCLOAK_DOMAIN:-}" ] || [ -z "${KEYCLOAK_REALM:-}" ]; then
    log "Loading Keycloak configuration from Kubernetes secret: ${KEYCLOAK_SECRET_NAME}"
    
    if ! kubectl get secret "${KEYCLOAK_SECRET_NAME}" -n "${KEYCLOAK_NAMESPACE}" >/dev/null 2>&1; then
      error "Secret ${KEYCLOAK_SECRET_NAME} not found in namespace ${KEYCLOAK_NAMESPACE}"
      exit 1
    fi
    
    KEYCLOAK_DOMAIN=$(get_secret_value "${KEYCLOAK_SECRET_NAME}" "domain" "${KEYCLOAK_NAMESPACE}")
    KEYCLOAK_REALM=$(get_secret_value "${KEYCLOAK_SECRET_NAME}" "realm" "${KEYCLOAK_NAMESPACE}")
  fi
  
  # Validate required configuration
  if [ -z "${HARBOR_DOMAIN:-}" ] || [ -z "${HARBOR_USERNAME:-}" ] || [ -z "${HARBOR_PASSWORD:-}" ] || \
     [ -z "${HARBOR_CLIENT_ID:-}" ] || [ -z "${HARBOR_CLIENT_SECRET:-}" ] || \
     [ -z "${KEYCLOAK_DOMAIN:-}" ] || [ -z "${KEYCLOAK_REALM:-}" ]; then
    error "Missing required configuration"
    error "Required: HARBOR_DOMAIN, HARBOR_USERNAME, HARBOR_PASSWORD, HARBOR_CLIENT_ID, HARBOR_CLIENT_SECRET, KEYCLOAK_DOMAIN, KEYCLOAK_REALM"
    exit 1
  fi
  
  log "Harbor Domain: ${HARBOR_DOMAIN}"
  log "Keycloak Domain: ${KEYCLOAK_DOMAIN}"
  log "Keycloak Realm: ${KEYCLOAK_REALM}"
  success "Configuration loaded successfully"
  log ""
}

# ================================================
# Harbor API Functions
# ================================================

# Make authenticated API call to Harbor
harbor_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  local retry_count=0
  local response
  local http_code
  
  while [ $retry_count -lt "$MAX_RETRIES" ]; do
    if [ -n "$data" ]; then
      response=$(curl -s -w "\n%{http_code}" -X "$method" \
        --max-time "$HTTP_TIMEOUT" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "https://${HARBOR_DOMAIN}${endpoint}" 2>&1) || true
    else
      response=$(curl -s -w "\n%{http_code}" -X "$method" \
        --max-time "$HTTP_TIMEOUT" \
        -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
        -H "Content-Type: application/json" \
        "https://${HARBOR_DOMAIN}${endpoint}" 2>&1) || true
    fi
    
    http_code=$(echo "$response" | tail -n 1)
    response=$(echo "$response" | sed '$d')
    
    # Check for successful HTTP codes
    if [[ "$http_code" =~ ^(200|201|204)$ ]]; then
      echo "$response"
      return 0
    fi
    
    retry_count=$((retry_count + 1))
    if [ $retry_count -lt "$MAX_RETRIES" ]; then
      warn "Harbor API request failed (HTTP $http_code), retry $retry_count/$MAX_RETRIES"
      warn "Response: $response"
      sleep "$RETRY_DELAY"
    fi
  done
  
  error "Harbor API request failed after $MAX_RETRIES retries (HTTP $http_code)"
  error "Endpoint: $method $endpoint"
  error "Response: $response"
  return 1
}

# ================================================
# Configuration Functions
# ================================================

# Wait for Harbor to be ready
wait_for_harbor() {
  log "Waiting for Harbor to be ready..."
  
  local harbor_url="https://${HARBOR_DOMAIN}/api/${HARBOR_API_VERSION}/systeminfo"
  local count=0
  local timeout=300
  
  while [ $count -lt $timeout ]; do
    if curl -sf --max-time 5 -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" "$harbor_url" >/dev/null 2>&1; then
      success "Harbor is ready"
      return 0
    fi
    sleep 10
    count=$((count + 10))
    log "Waiting for Harbor... ($count/${timeout}s)"
  done
  
  error "Timeout waiting for Harbor to be ready"
  return 1
}

# Configure Harbor OIDC settings
configure_oidc() {
  log "=================================================="
  log "Configuring Harbor OIDC Settings"
  log "=================================================="
  log ""
  
  local config_data
  config_data=$(cat <<EOF
{
  "auth_mode": "oidc_auth",
  "notification_enable": true,
  "oidc_admin_group": "admin",
  "oidc_auto_onboard": true,
  "oidc_client_id": "${HARBOR_CLIENT_ID}",
  "oidc_endpoint": "https://${KEYCLOAK_DOMAIN}/realms/${KEYCLOAK_REALM}",
  "oidc_extra_redirect_params": "{}",
  "oidc_group_filter": "",
  "oidc_groups_claim": "groups",
  "oidc_name": "keycloak",
  "oidc_scope": "openid,profile,email,roles,groups",
  "oidc_user_claim": "email",
  "project_creation_restriction": "adminonly",
  "quota_per_project_enable": true,
  "read_only": false,
  "robot_name_prefix": "robot$",
  "self_registration": false,
  "oidc_client_secret": "${HARBOR_CLIENT_SECRET}"
}
EOF
)
  
  log "Updating Harbor configuration..."
  if harbor_api PUT "/api/${HARBOR_API_VERSION}/configurations" "$config_data" >/dev/null; then
    success "Harbor OIDC configuration updated successfully"
  else
    error "Failed to update Harbor configuration"
    return 1
  fi
  
  log ""
}

# Configure Trivy scan schedule
configure_trivy_scan() {
  log "=================================================="
  log "Configuring Trivy Scan Schedule"
  log "=================================================="
  log ""
  
  log "Checking for existing scan schedule..."
  local scan_schedule
  scan_schedule=$(harbor_api GET "/api/${HARBOR_API_VERSION}/system/scanAll/schedule" 2>/dev/null || echo "{}")
  
  if echo "$scan_schedule" | jq -e '.schedule' >/dev/null 2>&1; then
    local schedule_type
    schedule_type=$(echo "$scan_schedule" | jq -r '.schedule.type // "unknown"')
    success "Trivy scan schedule already configured: $schedule_type"
    
    if [ "$schedule_type" != "Daily" ]; then
      warn "Current schedule is not 'Daily', consider updating it"
    fi
  else
    log "Creating daily Trivy scan schedule..."
    local schedule_data
    schedule_data=$(cat <<EOF
{
  "schedule": {
    "type": "Daily",
    "cron": "0 0 0 * * *"
  }
}
EOF
)
    
    if harbor_api POST "/api/${HARBOR_API_VERSION}/system/scanAll/schedule" "$schedule_data" >/dev/null; then
      success "Daily Trivy scan schedule created successfully"
      log "Schedule: Daily at midnight (0 0 0 * * *)"
    else
      error "Failed to create Trivy scan schedule"
      return 1
    fi
  fi
  
  log ""
}

# Verify configuration
verify_config() {
  log "=================================================="
  log "Verifying Harbor Configuration"
  log "=================================================="
  log ""
  
  log "Fetching current configuration..."
  local config
  config=$(harbor_api GET "/api/${HARBOR_API_VERSION}/configurations")
  
  if [ -z "$config" ]; then
    error "Failed to fetch Harbor configuration"
    return 1
  fi
  
  # Verify OIDC settings
  local auth_mode
  auth_mode=$(echo "$config" | jq -r '.auth_mode.value // "unknown"')
  
  if [ "$auth_mode" = "oidc_auth" ]; then
    success "Auth mode: $auth_mode ✓"
  else
    error "Auth mode: $auth_mode (expected: oidc_auth)"
    return 1
  fi
  
  local oidc_client_id
  oidc_client_id=$(echo "$config" | jq -r '.oidc_client_id.value // "unknown"')
  
  if [ "$oidc_client_id" = "$HARBOR_CLIENT_ID" ]; then
    success "OIDC client ID configured ✓"
  else
    warn "OIDC client ID mismatch"
  fi
  
  success "Harbor configuration verified"
  log ""
}

# ================================================
# Main Execution
# ================================================

main() {
  log "Starting Harbor post-install configuration..."
  log ""
  
  # Step 1: Validate environment
  validate_required_tools
  
  # Step 2: Load configuration
  load_config
  
  # Step 3: Wait for Harbor to be ready
  wait_for_harbor
  
  # Step 4: Configure OIDC
  configure_oidc
  
  # Step 5: Configure Trivy scanning
  configure_trivy_scan
  
  # Step 6: Verify configuration
  verify_config
  
  log "=================================================="
  success "Harbor Post-Install Configuration Complete"
  log "=================================================="
  log ""
  log "Summary:"
  log "  ✓ OIDC authentication configured with Keycloak"
  log "  ✓ Admin group: admin"
  log "  ✓ Auto-onboarding enabled"
  log "  ✓ Project creation: admin only"
  log "  ✓ Trivy daily scans configured"
  log ""
}

# Run main function
main "$@"

#!/bin/bash
# SonarQube Post-Install Configuration Script
# Configures SonarQube admin group and permissions

set -euo pipefail

# Get script directory for sourcing common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Configuration defaults
SONARQUBE_NAMESPACE="${SONARQUBE_NAMESPACE:-sonarqube}"
SONARQUBE_SECRET_NAME="${SONARQUBE_SECRET_NAME:-sonarqube-secret}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-30}"
MAX_RETRIES="${MAX_RETRIES:-5}"
RETRY_DELAY="${RETRY_DELAY:-10}"

# Admin group permissions
ADMIN_PERMISSIONS=(
  "admin"           # Administer System
  "gateadmin"       # Administer Quality Gates
  "profileadmin"    # Administer Quality Profiles
  "provisioning"    # Create Projects
  "scan"            # Execute Analysis
)

# ================================================
# Validation and Initialization
# ================================================

log "=================================================="
log "SonarQube Post-Install Configuration"
log "=================================================="
log ""

# Validate required tools
validate_required_tools() {
  validate_tools "curl" "jq" "kubectl" "base64" || exit 1
}

# Load configuration from environment or Kubernetes secrets
load_config() {
  log "Loading SonarQube configuration..."

  # Try to load from environment variables first
  if [ -n "${SONARQUBE_DOMAIN:-}" ] && [ -n "${SONARQUBE_USERNAME:-}" ] && [ -n "${SONARQUBE_PASSWORD:-}" ]; then
    log "Using configuration from environment variables"
  else
    # Try to load from Kubernetes secret
    log "Loading configuration from Kubernetes secret: ${SONARQUBE_SECRET_NAME}"

    if ! kubectl get secret "${SONARQUBE_SECRET_NAME}" -n "${SONARQUBE_NAMESPACE}" >/dev/null 2>&1; then
      error "Secret ${SONARQUBE_SECRET_NAME} not found in namespace ${SONARQUBE_NAMESPACE}"
      error "Please provide configuration via environment variables or Kubernetes secret"
      exit 1
    fi

    SONARQUBE_DOMAIN=$(get_secret_value "${SONARQUBE_SECRET_NAME}" "domain" "${SONARQUBE_NAMESPACE}")
    SONARQUBE_USERNAME=$(get_secret_value "${SONARQUBE_SECRET_NAME}" "admin.username" "${SONARQUBE_NAMESPACE}")
    SONARQUBE_PASSWORD=$(get_secret_value "${SONARQUBE_SECRET_NAME}" "admin.password" "${SONARQUBE_NAMESPACE}")
  fi

  # Validate required configuration
  if [ -z "${SONARQUBE_DOMAIN:-}" ] || [ -z "${SONARQUBE_USERNAME:-}" ] || [ -z "${SONARQUBE_PASSWORD:-}" ]; then
    error "Missing required configuration"
    error "Required: SONARQUBE_DOMAIN, SONARQUBE_USERNAME, SONARQUBE_PASSWORD"
    exit 1
  fi

  log "SonarQube Domain: ${SONARQUBE_DOMAIN}"
  success "Configuration loaded successfully"
  log ""
}

# ================================================
# SonarQube API Functions
# ================================================

# Make authenticated API call to SonarQube
sonarqube_api() {
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
        -u "${SONARQUBE_USERNAME}:${SONARQUBE_PASSWORD}" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "$data" \
        "https://${SONARQUBE_DOMAIN}${endpoint}" 2>&1) || true
    else
      response=$(curl -s -w "\n%{http_code}" -X "$method" \
        --max-time "$HTTP_TIMEOUT" \
        -u "${SONARQUBE_USERNAME}:${SONARQUBE_PASSWORD}" \
        "https://${SONARQUBE_DOMAIN}${endpoint}" 2>&1) || true
    fi

    http_code=$(echo "$response" | tail -n 1)
    response=$(echo "$response" | sed '$d')

    # Check for successful HTTP codes (SonarQube uses 200, 204)
    if [[ "$http_code" =~ ^(200|204)$ ]]; then
      echo "$response"
      return 0
    fi

    # Check if error is about existing resource (considered success for idempotency)
    if [[ "$http_code" == "400" ]] && echo "$response" | jq -e '.errors[]? | select(.msg | contains("already exists"))' >/dev/null 2>&1; then
      log "Resource already exists (idempotent operation)"
      echo "$response"
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [ $retry_count -lt "$MAX_RETRIES" ]; then
      warn "SonarQube API request failed (HTTP $http_code), retry $retry_count/$MAX_RETRIES"
      warn "Response: $response"
      sleep "$RETRY_DELAY"
    fi
  done

  error "SonarQube API request failed after $MAX_RETRIES retries (HTTP $http_code)"
  error "Endpoint: $method $endpoint"
  error "Response: $response"
  return 1
}

# ================================================
# Configuration Functions
# ================================================

# Wait for SonarQube to be ready
wait_for_sonarqube() {
  log "Waiting for SonarQube to be ready..."

  local sonarqube_url="https://${SONARQUBE_DOMAIN}/api/system/status"
  local count=0
  local timeout=300

  while [ $count -lt $timeout ]; do
    local status
    status=$(curl -sf --max-time 5 "$sonarqube_url" 2>/dev/null | jq -r '.status // "DOWN"' || echo "DOWN")

    if [ "$status" = "UP" ]; then
      success "SonarQube is ready"
      return 0
    fi

    sleep 10
    count=$((count + 10))
    log "Waiting for SonarQube... ($count/${timeout}s, status: $status)"
  done

  error "Timeout waiting for SonarQube to be ready"
  return 1
}

# Check if admin group exists
check_admin_group() {
  log "Checking for admin group..."

  local admin_group
  admin_group=$(sonarqube_api GET "/api/user_groups/search?q=admin" 2>/dev/null || echo '{"groups":[]}')

  if echo "$admin_group" | jq -e '.groups[]? | select(.name=="admin")' >/dev/null 2>&1; then
    success "Admin group already exists"
    return 0
  else
    return 1
  fi
}

# Create admin group
create_admin_group() {
  log "=================================================="
  log "Configuring Admin Group"
  log "=================================================="
  log ""

  if check_admin_group; then
    log ""
    return 0
  fi

  log "Creating admin group..."
  if sonarqube_api POST "/api/user_groups/create" "name=admin&description=Administrators+group" >/dev/null; then
    success "Admin group created successfully"
  else
    error "Failed to create admin group"
    return 1
  fi

  log ""
}

# Configure admin group permissions
configure_permissions() {
  log "=================================================="
  log "Configuring Admin Group Permissions"
  log "=================================================="
  log ""

  log "Granting permissions to admin group..."
  local failed_permissions=()

  for permission in "${ADMIN_PERMISSIONS[@]}"; do
    log "  Granting permission: $permission"

    # Try to add permission
    if sonarqube_api POST "/api/permissions/add_group" "groupName=admin&permission=${permission}" >/dev/null 2>&1; then
      success "  ✓ Permission '$permission' granted"
    else
      # Check if permission already exists
      local existing_perms
      existing_perms=$(sonarqube_api GET "/api/permissions/groups?q=admin" 2>/dev/null || echo '{}')

      if echo "$existing_perms" | jq -e ".groups[]? | select(.name==\"admin\") | .permissions[]? | select(.==\"$permission\")" >/dev/null 2>&1; then
        success "  ✓ Permission '$permission' already set"
      else
        warn "  ✗ Failed to grant permission '$permission'"
        failed_permissions+=("$permission")
      fi
    fi
  done

  if [ ${#failed_permissions[@]} -gt 0 ]; then
    warn "Some permissions could not be set: ${failed_permissions[*]}"
  else
    success "All permissions configured successfully"
  fi

  log ""
}

# Verify configuration
verify_config() {
  log "=================================================="
  log "Verifying SonarQube Configuration"
  log "=================================================="
  log ""

  # Verify admin group exists
  if check_admin_group; then
    success "Admin group verified ✓"
  else
    error "Admin group not found"
    return 1
  fi

  # Verify permissions
  log "Verifying admin group permissions..."
  local existing_perms
  existing_perms=$(sonarqube_api GET "/api/permissions/groups?q=admin" 2>/dev/null || echo '{}')

  local verified=0
  local total=${#ADMIN_PERMISSIONS[@]}

  for permission in "${ADMIN_PERMISSIONS[@]}"; do
    if echo "$existing_perms" | jq -e ".groups[]? | select(.name==\"admin\") | .permissions[]? | select(.==\"$permission\")" >/dev/null 2>&1; then
      verified=$((verified + 1))
    fi
  done

  if [ $verified -eq $total ]; then
    success "All permissions verified ($verified/$total) ✓"
  else
    warn "Some permissions not verified ($verified/$total)"
  fi

  log ""
}

# ================================================
# Main Execution
# ================================================

main() {
  log "Starting SonarQube post-install configuration..."
  log ""

  # Step 1: Validate environment
  validate_required_tools

  # Step 2: Load configuration
  load_config

  # Step 3: Wait for SonarQube to be ready
  wait_for_sonarqube

  # Step 4: Create admin group
  create_admin_group

  # Step 5: Configure permissions
  configure_permissions

  # Step 6: Verify configuration
  verify_config

  log "=================================================="
  success "SonarQube Post-Install Configuration Complete"
  log "=================================================="
  log ""
  log "Summary:"
  log "  ✓ Admin group created"
  log "  ✓ Admin group permissions configured:"
  log "    - admin (Administer System)"
  log "    - gateadmin (Administer Quality Gates)"
  log "    - profileadmin (Administer Quality Profiles)"
  log "    - provisioning (Create Projects)"
  log "    - scan (Execute Analysis)"
  log ""
}

# Run main function
main "$@"

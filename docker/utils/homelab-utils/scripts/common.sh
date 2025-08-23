#!/bin/bash
# Common utilities for platform configuration scripts

# Colors for output
COLOR_RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${COLOR_RED}[ERROR]${NC} $1"
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Wait for a Kubernetes resource to be ready
wait_for_resource() {
  local resource_type="$1"
  local resource_name="$2"
  local namespace="${3:-default}"
  local timeout="${4:-300}"

  log "Waiting for $resource_type/$resource_name to be ready in namespace $namespace..."
  kubectl wait --for=condition=available "$resource_type/$resource_name" -n "$namespace" --timeout="${timeout}s" || {
    error "Timeout waiting for $resource_type/$resource_name"
    return 1
  }
  success "$resource_type/$resource_name is ready"
}

# Wait for a secret to exist
wait_for_secret() {
  local secret_name="$1"
  local namespace="${2:-default}"
  local timeout="${3:-300}"

  log "Waiting for secret $secret_name in namespace $namespace..."
  local count=0
  while [ $count -lt $timeout ]; do
    if kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
      success "Secret $secret_name found"
      return 0
    fi
    sleep 10
    count=$((count + 10))
  done

  error "Timeout waiting for secret $secret_name"
  return 1
}

# Get secret value
get_secret_value() {
  local secret_name="$1"
  local key="$2"
  local namespace="${3:-default}"

  kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" | base64 -d
}

# Create or update a configmap
create_or_update_configmap() {
  local configmap_name="$1"
  local namespace="$2"
  shift 2

  log "Creating/updating configmap $configmap_name in namespace $namespace"
  kubectl create configmap "$configmap_name" -n "$namespace" "$@" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Restart a deployment
restart_deployment() {
  local deployment_name="$1"
  local namespace="${2:-default}"
  local timeout="${3:-300}"

  log "Restarting deployment $deployment_name in namespace $namespace..."
  kubectl rollout restart "deployment/$deployment_name" -n "$namespace"
  kubectl rollout status "deployment/$deployment_name" -n "$namespace" --timeout="${timeout}s"
  success "Deployment $deployment_name restarted successfully"
}

# Get ingress host from service values
get_service_host() {
  local service_name="$1"
  local chart_name="${2:-$service_name}"

  # Try to get from common ingress patterns
  kubectl get ingress -A -o jsonpath="{.items[?(@.metadata.labels['app\.kubernetes\.io/name']=='$service_name')].spec.rules[0].host}" 2>/dev/null || \
  kubectl get ingress -A -o jsonpath="{.items[?(@.metadata.labels['app\.kubernetes\.io/instance']=='$chart_name')].spec.rules[0].host}" 2>/dev/null || \
  echo ""
}

# HTTP request with retry
http_request() {
  local method="$1"
  local url="$2"
  local max_retries="${3:-3}"
  shift 3

  local count=0
  while [ $count -lt $max_retries ]; do
    if curl -sf -X "$method" "$url" "$@"; then
      return 0
    fi
    count=$((count + 1))
    warn "HTTP request failed, retry $count/$max_retries"
    sleep 5
  done

  error "HTTP request failed after $max_retries retries"
  return 1
}

# Wait for HTTP endpoint to be ready
wait_for_http() {
  local url="$1"
  local timeout="${2:-300}"

  log "Waiting for HTTP endpoint to be ready: $url"
  local count=0
  while [ $count -lt $timeout ]; do
    if curl -sf "$url" >/dev/null 2>&1; then
      success "HTTP endpoint is ready: $url"
      return 0
    fi
    sleep 10
    count=$((count + 10))
  done

  error "Timeout waiting for HTTP endpoint: $url"
  return 1
}

#!/bin/bash
# Common utilities for homelab configuration scripts

set -euo pipefail

# ================================================
# Color Codes
# ================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ================================================
# Logging Functions
# ================================================

log() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# ================================================
# Validation Functions
# ================================================

# Validate that required command-line tools are available
# Usage: validate_tools "curl" "jq" "kubectl" "base64"
validate_tools() {
  local tools=("$@")
  local missing=()

  for tool in "${tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing required tools: ${missing[*]}"
    return 1
  fi

  success "All required tools are available"
  return 0
}

# ================================================
# Kubernetes Secret Functions
# ================================================

# Get a value from a Kubernetes secret
# Usage: get_secret_value "secret-name" "key" "namespace"
get_secret_value() {
  local secret_name="$1"
  local key="$2"
  local namespace="${3:-default}"

  if ! kubectl get secret "$secret_name" -n "$namespace" >/dev/null 2>&1; then
    error "Secret $secret_name not found in namespace $namespace"
    return 1
  fi

  local value
  value=$(kubectl get secret "$secret_name" -n "$namespace" -o jsonpath="{.data.$key}" 2>/dev/null | base64 -d 2>/dev/null)

  if [ -z "$value" ]; then
    error "Key $key not found in secret $secret_name"
    return 1
  fi

  echo "$value"
  return 0
}

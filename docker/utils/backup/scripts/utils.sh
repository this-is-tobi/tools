#!/bin/bash

# Common utility functions for backup scripts

# Logging functions
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Validate required environment variables
# Usage: validate_required_vars "VAR1" "VAR2" "VAR3"
validate_required_vars() {
  local missing_vars=()
  
  for var in "$@"; do
    if [ -z "${!var}" ]; then
      missing_vars+=("$var")
    fi
  done
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
      echo "  - $var" >&2
    done
    exit 1
  fi
}

# Validate port is numeric
# Usage: validate_port "$PORT_VAR_NAME" "$PORT_VALUE"
validate_port() {
  local var_name="$1"
  local port_value="$2"
  
  if ! [[ "$port_value" =~ ^[0-9]+$ ]]; then
    error "${var_name} must be a number, got: ${port_value}"
    exit 1
  fi
  
  if [ "$port_value" -lt 1 ] || [ "$port_value" -gt 65535 ]; then
    error "${var_name} must be between 1 and 65535, got: ${port_value}"
    exit 1
  fi
}

# Configure rclone S3 remote
# Usage: configure_rclone_remote "remote_name" "$ENDPOINT" "$ACCESS_KEY" "$SECRET_KEY" "$PATH_STYLE"
configure_rclone_remote() {
  local remote_name="$1"
  local endpoint="$2"
  local access_key="$3"
  local secret_key="$4"
  local path_style="$5"
  
  log "Configuring rclone remote: ${remote_name}"
  
  rclone config delete "$remote_name" 2>/dev/null || true
  rclone config create "$remote_name" s3 \
    provider AWS \
    env_auth false \
    access_key_id "$access_key" \
    secret_access_key "$secret_key" \
    endpoint "$endpoint" \
    $([ "$path_style" = "true" ] && echo "force_path_style true")
  
  # Verify remote was created
  if ! rclone listremotes | grep -q "${remote_name}:"; then
    error "Failed to configure rclone remote: ${remote_name}"
    exit 1
  fi
}

# Cleanup old backups based on retention period
# Usage: cleanup_old_backups "remote:bucket/prefix" "$RETENTION" "$RCLONE_EXTRA_ARGS"
cleanup_old_backups() {
  local backup_path="$1"
  local retention="$2"
  local extra_args="$3"
  
  if [ -z "$retention" ]; then
    return 0
  fi
  
  log "Deleting backups older than ${retention} in '${backup_path}'"
  
  rclone delete ${extra_args} --min-age "$retention" "$backup_path"
  
  log "Cleanup completed"
}

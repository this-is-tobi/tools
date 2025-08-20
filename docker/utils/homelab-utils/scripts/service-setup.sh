#!/bin/bash
set -euo pipefail

# Source common utilities
source /scripts/common.sh

log "Starting custom service configuration for $SERVICE_NAME..."

# Wait for the service to be available if service URL is provided
if [ -n "${SERVICE_URL:-}" ]; then
  wait_for_http "$SERVICE_URL"
fi

# Execute custom configuration if service-config.sh exists
if [ -f "/config/service-config.sh" ]; then
  log "Executing custom service configuration script..."
  chmod +x /config/service-config.sh

  # Source the service configuration script
  source /config/service-config.sh

  success "Custom service configuration completed"
else
  log "No custom service configuration found"
fi

success "Service configuration completed for $SERVICE_NAME"

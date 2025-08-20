#!/bin/bash

# Post-install configuration script
# Handles service-specific post-installation tasks

set -e

source /scripts/common.sh

SERVICE_NAME=${SERVICE_NAME:-""}

if [[ -z "$SERVICE_NAME" ]]; then
  echo "ERROR: SERVICE_NAME environment variable is required"
  exit 1
fi

# Service-specific post-install configuration functions

configure_argo_workflows() {
  echo "Configuring Argo Workflows post-install..."

  # Create admin service account token
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: argo-workflows-server.service-account-token
  namespace: argo-workflows
  annotations:
    kubernetes.io/service-account.name: argo-workflows-server
type: kubernetes.io/service-account-token
EOF
  echo "✓ Argo Workflows admin service account token created"
}

configure_harbor() {
  echo "Configuring Harbor post-install..."

  # Wait for Harbor to be ready
  wait_for_service "harbor" "https://${DOMAIN}/api/v2.0/health"

  # Update Harbor configuration
  curl -X PUT "https://${DOMAIN}/api/v2.0/configurations" \
    -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d '{
      "auth_mode": "oidc_auth",
      "oidc_name": "Keycloak",
      "oidc_endpoint": "'${KEYCLOAK_URL}'/realms/'${KEYCLOAK_REALM}'",
      "oidc_client_id": "'${CLIENT_ID}'",
      "oidc_client_secret": "'${CLIENT_SECRET}'",
      "oidc_scope": "openid,profile,email",
      "oidc_verify_cert": true,
      "oidc_auto_onboard": true,
      "oidc_user_claim": "preferred_username",
      "oidc_group_claim": "groups",
      "oidc_admin_group": "admin"
    }'

  echo "✓ Harbor OIDC configuration updated"
}

configure_kubernetes_dashboard() {
  echo "Configuring Kubernetes Dashboard post-install..."

  # Get admin token
  ADMIN_TOKEN=$(kubectl get secret kubernetes-dashboard-admin -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 -d)

  # Store token in Vault
  vault_write "secret/kubernetes-dashboard" \
    admin.token="$ADMIN_TOKEN"

  echo "✓ Kubernetes Dashboard admin token stored in Vault"
}

configure_sonarqube() {
  echo "Configuring SonarQube post-install..."

  # Wait for SonarQube to be ready
  wait_for_service "sonarqube" "https://${DOMAIN}/api/system/status"

  # Check if admin group exists
  ADMIN_GROUP_EXISTS=$(curl -s -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" \
    "https://${DOMAIN}/api/user_groups/search?q=admin" | \
    jq -r '.groups[] | select(.name=="admin") | .name' || echo "")

  if [[ -z "$ADMIN_GROUP_EXISTS" ]]; then
    # Create admin group
    curl -X POST "https://${DOMAIN}/api/user_groups/create?name=admin&description=admin" \
      -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}"
    echo "✓ Admin group created"
  else
    echo "✓ Admin group already exists"
  fi

  # Add admin permissions to admin group
  PERMISSIONS=("admin" "gateadmin" "profileadmin" "provisioning" "scan")
  for permission in "${PERMISSIONS[@]}"; do
    curl -X POST "https://${DOMAIN}/api/permissions/add_group?groupName=admin&permission=${permission}" \
      -u "${ADMIN_USERNAME}:${ADMIN_PASSWORD}" || true
  done

  echo "✓ SonarQube admin group permissions configured"
}

# Main execution
echo "Starting post-install configuration for service: $SERVICE_NAME"

# Load service-specific configuration
load_service_config "$SERVICE_NAME"

case "$SERVICE_NAME" in
  "argo-workflows")
    configure_argo_workflows
    ;;
  "harbor")
    configure_harbor
    ;;
  "kubernetes-dashboard")
    configure_kubernetes_dashboard
    ;;
  "sonarqube")
    configure_sonarqube
    ;;
  *)
    echo "No post-install configuration defined for service: $SERVICE_NAME"
    ;;
esac

echo "✓ Post-install configuration completed for service: $SERVICE_NAME"

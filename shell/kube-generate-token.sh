#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_WHITE='\033[1;37m'
COLOR_BOLD='\033[1m'

# Defaults
NAMESPACE=""
SERVICE_ACCOUNT_NAME=""
RBAC_TYPE="role"
RBAC_NAME=""
TOKEN_DURATION="24h"
OUTPUT_FORMAT="token"
OUTPUT_FILE=""
ALLOW_SECRETS="false"
TOKEN=""
KUBECONFIG_DIR="$HOME/.kube/config.d"

# Script helper
TEXT_HELPER="
This script generates a Kubernetes token associated with a service account and RBAC.

The token and kubeconfig are the only things printed on stdout, progress messages go to stderr,
so the output can be redirected or captured as is.

Available flags:
  -s    Service account name (required).
  -n    Kubernetes namespace where the service account will be created.
        Default: the namespace of the current kubectl context, or 'default'.
  -t    RBAC type ('role' or 'clusterrole').
        Default: '$RBAC_TYPE'.
  -r    RBAC name. If not provided, will use service account name with '-rbac' suffix.
  -d    Token duration (e.g., '1h', '24h', '720h'). The API server may cap it.
        Default: '$TOKEN_DURATION'.
  -f    Output format ('token', 'kubeconfig', 'both').
        Default: '$OUTPUT_FORMAT'.
  -o    Write the kubeconfig to this file (mode 600) instead of stdout.
  -S    Also grant get/list/watch on secrets (cluster-wide with '-t clusterrole').
        Off by default: read access to secrets exposes every credential they hold.
  -h    Print script help.

The created role grants get/list/watch on pods, services, configmaps, deployments and
replicasets. Existing service accounts and roles are reused as they are.

Example:
  ./kube-generate-token.sh \\
    -s my-service-account \\
    -n my-namespace \\
    -t role \\
    -r custom-role \\
    -d 24h \\
    -f kubeconfig \\
    -o ~/.kube/config.d/my-service-account
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Progress messages go to stderr so stdout only carries the token / kubeconfig
log () {
  echo -e "$@" >&2
}

create_service_account() {
  log "${COLOR_BLUE}Creating service account '$SERVICE_ACCOUNT_NAME' in namespace '$NAMESPACE'...${COLOR_OFF}"

  cat <<EOF | kubectl apply -f - >&2
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
EOF

  log "${COLOR_GREEN}✓ Service account created successfully${COLOR_OFF}"
}

create_rbac() {
  local rbac_kind=""
  local rbac_api_version=""
  local core_resources='"pods", "services", "configmaps"'

  if [ "$RBAC_TYPE" = "clusterrole" ]; then
    rbac_kind="ClusterRole"
    rbac_api_version="rbac.authorization.k8s.io/v1"
    log "${COLOR_BLUE}Creating ClusterRole '$RBAC_NAME'...${COLOR_OFF}"
  else
    rbac_kind="Role"
    rbac_api_version="rbac.authorization.k8s.io/v1"
    log "${COLOR_BLUE}Creating Role '$RBAC_NAME' in namespace '$NAMESPACE'...${COLOR_OFF}"
  fi
  if [ "$ALLOW_SECRETS" = "true" ]; then
    core_resources="$core_resources, \"secrets\""
  fi

  # Create RBAC resource
  cat <<EOF | kubectl apply -f - >&2
apiVersion: $rbac_api_version
kind: $rbac_kind
metadata:
  name: $RBAC_NAME
$([ "$RBAC_TYPE" = "role" ] && echo "  namespace: $NAMESPACE")
rules:
- apiGroups: [""]
  resources: [$core_resources]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]
EOF

  # Create RoleBinding or ClusterRoleBinding
  local binding_kind=""
  local binding_name="${RBAC_NAME}-binding"

  if [ "$RBAC_TYPE" = "clusterrole" ]; then
    binding_kind="ClusterRoleBinding"
    log "${COLOR_BLUE}Creating ClusterRoleBinding '$binding_name'...${COLOR_OFF}"
  else
    binding_kind="RoleBinding"
    log "${COLOR_BLUE}Creating RoleBinding '$binding_name' in namespace '$NAMESPACE'...${COLOR_OFF}"
  fi

  cat <<EOF | kubectl apply -f - >&2
apiVersion: rbac.authorization.k8s.io/v1
kind: $binding_kind
metadata:
  name: $binding_name
$([ "$RBAC_TYPE" = "role" ] && echo "  namespace: $NAMESPACE")
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
roleRef:
  kind: $rbac_kind
  name: $RBAC_NAME
  apiGroup: rbac.authorization.k8s.io
EOF

  log "${COLOR_GREEN}✓ RBAC resources created successfully${COLOR_OFF}"
}

# Sets TOKEN rather than echoing it: a command substitution would also capture the log lines
generate_token() {
  log "${COLOR_BLUE}Generating token for service account '$SERVICE_ACCOUNT_NAME'...${COLOR_OFF}"

  TOKEN=$(kubectl create token "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE" --duration="$TOKEN_DURATION")

  if [ -z "$TOKEN" ]; then
    log "${COLOR_RED}Error: Failed to generate token${COLOR_OFF}"
    exit 1
  fi

  log "${COLOR_GREEN}✓ Token generated successfully${COLOR_OFF}"
}

generate_kubeconfig() {
  local server cluster_name ca_data
  # Explicit returns: errexit does not apply when the caller tests this function
  server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}') || return 1
  cluster_name=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}') || return 1
  # --flatten embeds a CA given as a file path, so the kubeconfig works on another machine
  ca_data=$(kubectl config view --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}') || return 1
  if [ -z "$server" ]; then
    log "${COLOR_RED}Error: No API server found in the current kubectl context${COLOR_OFF}"
    return 1
  fi

  log "${COLOR_BLUE}Generating kubeconfig for service account '$SERVICE_ACCOUNT_NAME'...${COLOR_OFF}"

  cat <<EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $ca_data
    server: $server
  name: $cluster_name
contexts:
- context:
    cluster: $cluster_name
    namespace: $NAMESPACE
    user: $SERVICE_ACCOUNT_NAME
  name: $SERVICE_ACCOUNT_NAME@$cluster_name
current-context: $SERVICE_ACCOUNT_NAME@$cluster_name
users:
- name: $SERVICE_ACCOUNT_NAME
  user:
    token: $TOKEN
EOF
}

# The file holds a bearer token: build it in a private temporary file next to the target and
# move it in place, so it is never readable by others, even when it replaces an existing file.
write_kubeconfig() {
  local dir tmp
  dir="$(dirname "$OUTPUT_FILE")"
  (umask 077 && mkdir -p "$dir")
  tmp="$(mktemp "${OUTPUT_FILE}.XXXXXX")"
  if ! generate_kubeconfig > "$tmp"; then
    rm -f "$tmp"
    log "${COLOR_RED}Error: Failed to generate the kubeconfig${COLOR_OFF}"
    exit 1
  fi
  chmod 600 "$tmp"
  mv -f "$tmp" "$OUTPUT_FILE"
  log "${COLOR_GREEN}✓ Kubeconfig written to '$OUTPUT_FILE'${COLOR_OFF}"
}

# Parse options
while getopts hs:n:t:r:d:f:o:S flag; do
  case "${flag}" in
    s)
      SERVICE_ACCOUNT_NAME=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    t)
      RBAC_TYPE=${OPTARG};;
    r)
      RBAC_NAME=${OPTARG};;
    d)
      TOKEN_DURATION=${OPTARG};;
    f)
      OUTPUT_FORMAT=${OPTARG};;
    o)
      OUTPUT_FILE=${OPTARG};;
    S)
      ALLOW_SECRETS="true";;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Validate required parameters
if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  log "${COLOR_RED}Error: Service account name is required. Use -s flag to specify the service account name.${COLOR_OFF}"
  print_help >&2
  exit 1
fi

# Set default RBAC name if not provided
if [ -z "$RBAC_NAME" ]; then
  RBAC_NAME="${SERVICE_ACCOUNT_NAME}-rbac"
fi

# Validate RBAC type
if [ "$RBAC_TYPE" != "role" ] && [ "$RBAC_TYPE" != "clusterrole" ]; then
  log "${COLOR_RED}Error: RBAC type must be 'role' or 'clusterrole'.${COLOR_OFF}"
  exit 1
fi

# Validate output format
if [ "$OUTPUT_FORMAT" != "token" ] && [ "$OUTPUT_FORMAT" != "kubeconfig" ] && [ "$OUTPUT_FORMAT" != "both" ]; then
  log "${COLOR_RED}Error: Output format must be 'token', 'kubeconfig', or 'both'.${COLOR_OFF}"
  exit 1
fi
if [ -n "$OUTPUT_FILE" ] && [ "$OUTPUT_FORMAT" = "token" ]; then
  log "${COLOR_RED}Error: -o writes a kubeconfig, use it with '-f kubeconfig' or '-f both'.${COLOR_OFF}"
  exit 1
fi

if [ -z "$NAMESPACE" ]; then
  NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}' 2>/dev/null || true)"
  NAMESPACE="${NAMESPACE:-default}"
fi

log "${COLOR_BOLD}Kubernetes Token Generator${COLOR_OFF}"
log "=========================="
log "Service Account: ${COLOR_YELLOW}$SERVICE_ACCOUNT_NAME${COLOR_OFF}"
log "Namespace:       ${COLOR_BLUE}$NAMESPACE${COLOR_OFF}"
log "RBAC Type:       $RBAC_TYPE"
log "RBAC Name:       $RBAC_NAME"
log "Secrets Access:  $ALLOW_SECRETS"
log "Token Duration:  $TOKEN_DURATION"
log "Output Format:   $OUTPUT_FORMAT"
log

# Check if service account already exists
if kubectl get serviceaccount "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  log "${COLOR_YELLOW}⚠ Service account '$SERVICE_ACCOUNT_NAME' already exists in namespace '$NAMESPACE'${COLOR_OFF}"
else
  create_service_account
fi

# Check if RBAC already exists
rbac_exists=false
if [ "$RBAC_TYPE" = "clusterrole" ]; then
  kubectl get clusterrole "$RBAC_NAME" >/dev/null 2>&1 && rbac_exists=true
else
  kubectl get role "$RBAC_NAME" -n "$NAMESPACE" >/dev/null 2>&1 && rbac_exists=true
fi

if [ "$rbac_exists" = true ]; then
  log "${COLOR_YELLOW}⚠ RBAC '$RBAC_NAME' already exists, its rules are left unchanged${COLOR_OFF}"
else
  create_rbac
fi

log

# Generate token
generate_token

log
log "${COLOR_BOLD}Output:${COLOR_OFF}"
log "======="

case "$OUTPUT_FORMAT" in
  "token")
    log "${COLOR_WHITE}Token:${COLOR_OFF}"
    echo "$TOKEN"
    ;;
  "kubeconfig")
    log "${COLOR_WHITE}Kubeconfig:${COLOR_OFF}"
    if [ -n "$OUTPUT_FILE" ]; then
      write_kubeconfig
    else
      generate_kubeconfig
    fi
    ;;
  "both")
    log "${COLOR_WHITE}Token:${COLOR_OFF}"
    echo "$TOKEN"
    log
    log "${COLOR_WHITE}Kubeconfig:${COLOR_OFF}"
    if [ -n "$OUTPUT_FILE" ]; then
      write_kubeconfig
    else
      generate_kubeconfig
    fi
    ;;
esac

log
log "${COLOR_GREEN}✓ Kubernetes token generation completed successfully!${COLOR_OFF}"
log
log "${COLOR_BOLD}Usage Examples:${COLOR_OFF}"
log "==============="
log "# Test token with kubectl:"
log "kubectl --token=\"\$TOKEN\" get pods -n $NAMESPACE"
log
log "# Save kubeconfig to file:"
log "./kube-generate-token.sh -s $SERVICE_ACCOUNT_NAME -n $NAMESPACE -f kubeconfig -o $KUBECONFIG_DIR/$SERVICE_ACCOUNT_NAME"
log
log "# Use kubeconfig:"
log "export KUBECONFIG=$KUBECONFIG_DIR/$SERVICE_ACCOUNT_NAME"
log "kubectl get pods"

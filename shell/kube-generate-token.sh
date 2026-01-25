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
CLUSTER="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')"
NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
SERVICE_ACCOUNT_NAME=""
RBAC_TYPE="role"
RBAC_NAME=""
TOKEN_DURATION="8760h" # 1 year
OUTPUT_FORMAT="token"
KUBECONFIG_DIR="$HOME/.kube/config.d"

# Script helper
TEXT_HELPER="
This script generates a Kubernetes token associated with a service account and RBAC.

Available flags:
  -s    Service account name (required).
  -n    Kubernetes namespace where the service account will be created.
        Default: '$NAMESPACE'.
  -t    RBAC type ('role' or 'clusterrole').
        Default: '$RBAC_TYPE'.
  -r    RBAC name. If not provided, will use service account name with '-rbac' suffix.
  -d    Token duration (e.g., '24h', '8760h', '365d').
        Default: '$TOKEN_DURATION'.
  -f    Output format ('token', 'kubeconfig', 'both').
        Default: '$OUTPUT_FORMAT'.
  -h    Print script help.

Example:
  ./generate-kube-token.sh \\
    -s my-service-account \\
    -n my-namespace \\
    -t role \\
    -r custom-role \\
    -d 24h \\
    -f kubeconfig
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

create_service_account() {
  echo -e "${COLOR_BLUE}Creating service account '$SERVICE_ACCOUNT_NAME' in namespace '$NAMESPACE'...${COLOR_OFF}"
  
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
EOF

  echo -e "${COLOR_GREEN}✓ Service account created successfully${COLOR_OFF}"
}

create_rbac() {
  local rbac_kind=""
  local rbac_api_version=""
  
  if [ "$RBAC_TYPE" = "clusterrole" ]; then
    rbac_kind="ClusterRole"
    rbac_api_version="rbac.authorization.k8s.io/v1"
    echo -e "${COLOR_BLUE}Creating ClusterRole '$RBAC_NAME'...${COLOR_OFF}"
  else
    rbac_kind="Role"
    rbac_api_version="rbac.authorization.k8s.io/v1"
    echo -e "${COLOR_BLUE}Creating Role '$RBAC_NAME' in namespace '$NAMESPACE'...${COLOR_OFF}"
  fi

  # Create RBAC resource
  cat <<EOF | kubectl apply -f -
apiVersion: $rbac_api_version
kind: $rbac_kind
metadata:
  name: $RBAC_NAME
$([ "$RBAC_TYPE" = "role" ] && echo "  namespace: $NAMESPACE")
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets"]
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
    echo -e "${COLOR_BLUE}Creating ClusterRoleBinding '$binding_name'...${COLOR_OFF}"
  else
    binding_kind="RoleBinding"
    echo -e "${COLOR_BLUE}Creating RoleBinding '$binding_name' in namespace '$NAMESPACE'...${COLOR_OFF}"
  fi

  cat <<EOF | kubectl apply -f -
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

  echo -e "${COLOR_GREEN}✓ RBAC resources created successfully${COLOR_OFF}"
}

generate_token() {
  echo -e "${COLOR_BLUE}Generating token for service account '$SERVICE_ACCOUNT_NAME'...${COLOR_OFF}"
  
  local token=$(kubectl create token $SERVICE_ACCOUNT_NAME -n $NAMESPACE --duration=$TOKEN_DURATION)
  
  if [ -z "$token" ]; then
    echo -e "${COLOR_RED}Error: Failed to generate token${COLOR_OFF}"
    exit 1
  fi
  
  echo -e "${COLOR_GREEN}✓ Token generated successfully${COLOR_OFF}"
  echo "$token"
}

generate_kubeconfig() {
  local token=$1
  local server=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
  local cluster_name=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
  local ca_data=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
  
  echo -e "${COLOR_BLUE}Generating kubeconfig for service account '$SERVICE_ACCOUNT_NAME'...${COLOR_OFF}"
  
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
    token: $token
EOF
}

# Parse options
while getopts hs:n:t:r:d:f: flag; do
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
    h | *)
      print_help
      exit 0;;
  esac
done

# Validate required parameters
if [ -z "$SERVICE_ACCOUNT_NAME" ]; then
  echo -e "${COLOR_RED}Error: Service account name is required. Use -s flag to specify the service account name.${COLOR_OFF}"
  print_help
  exit 1
fi

# Set default RBAC name if not provided
if [ -z "$RBAC_NAME" ]; then
  RBAC_NAME="${SERVICE_ACCOUNT_NAME}-rbac"
fi

# Validate RBAC type
if [ "$RBAC_TYPE" != "role" ] && [ "$RBAC_TYPE" != "clusterrole" ]; then
  echo -e "${COLOR_RED}Error: RBAC type must be 'role' or 'clusterrole'.${COLOR_OFF}"
  exit 1
fi

# Validate output format
if [ "$OUTPUT_FORMAT" != "token" ] && [ "$OUTPUT_FORMAT" != "kubeconfig" ] && [ "$OUTPUT_FORMAT" != "both" ]; then
  echo -e "${COLOR_RED}Error: Output format must be 'token', 'kubeconfig', or 'both'.${COLOR_OFF}"
  exit 1
fi

echo -e "${COLOR_BOLD}Kubernetes Token Generator${COLOR_OFF}"
echo "=========================="
echo -e "Service Account: ${COLOR_YELLOW}$SERVICE_ACCOUNT_NAME${COLOR_OFF}"
echo -e "Namespace:       ${COLOR_BLUE}$NAMESPACE${COLOR_OFF}"
echo -e "RBAC Type:       $RBAC_TYPE"
echo -e "RBAC Name:       $RBAC_NAME"
echo -e "Token Duration:  $TOKEN_DURATION"
echo -e "Output Format:   $OUTPUT_FORMAT"
echo

# Check if service account already exists
if kubectl get serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE >/dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}⚠ Service account '$SERVICE_ACCOUNT_NAME' already exists in namespace '$NAMESPACE'${COLOR_OFF}"
else
  create_service_account
fi

# Check if RBAC already exists
rbac_exists=false
if [ "$RBAC_TYPE" = "clusterrole" ]; then
  kubectl get clusterrole $RBAC_NAME >/dev/null 2>&1 && rbac_exists=true
else
  kubectl get role $RBAC_NAME -n $NAMESPACE >/dev/null 2>&1 && rbac_exists=true
fi

if [ "$rbac_exists" = true ]; then
  echo -e "${COLOR_YELLOW}⚠ RBAC '$RBAC_NAME' already exists${COLOR_OFF}"
else
  create_rbac
fi

echo

# Generate token
token=$(generate_token)

echo
echo -e "${COLOR_BOLD}Output:${COLOR_OFF}"
echo "======="

case "$OUTPUT_FORMAT" in
  "token")
    echo -e "${COLOR_WHITE}Token:${COLOR_OFF}"
    echo "$token"
    ;;
  "kubeconfig")
    mkdir -p "$KUBECONFIG_DIR"
    echo -e "${COLOR_WHITE}Kubeconfig:${COLOR_OFF}"
    generate_kubeconfig "$token"
    ;;
  "both")
    mkdir -p "$KUBECONFIG_DIR"
    echo -e "${COLOR_WHITE}Token:${COLOR_OFF}"
    echo "$token"
    echo
    echo -e "${COLOR_WHITE}Kubeconfig:${COLOR_OFF}"
    generate_kubeconfig "$token"
    ;;
esac

echo
echo -e "${COLOR_GREEN}✓ Kubernetes token generation completed successfully!${COLOR_OFF}"
echo
echo -e "${COLOR_BOLD}Usage Examples:${COLOR_OFF}"
echo "==============="
echo "# Test token with kubectl:"
echo "kubectl --token=\"\$TOKEN\" get pods -n $NAMESPACE"
echo
echo "# Save kubeconfig to file:"
echo "./generate-kube-token.sh -s $SERVICE_ACCOUNT_NAME -n $NAMESPACE -f kubeconfig > $KUBECONFIG_DIR/$SERVICE_ACCOUNT_NAME"
echo
echo "# Use kubeconfig:"
echo "export KUBECONFIG=$KUBECONFIG_DIR/$SERVICE_ACCOUNT_NAME"
echo "kubectl get pods"

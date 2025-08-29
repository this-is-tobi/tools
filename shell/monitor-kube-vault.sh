#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_WHITE='\033[1;37m'
COLOR_BOLD='\033[1m'

# Defaults
NAMESPACE="$(kubectl config view --minify -o jsonpath='{..namespace}')"
VAULT_NAME=""

# Script helper
TEXT_HELPER="This script aims to monitor HashiCorp Vault HA deployment status and cluster health.

Available flags:
  -v    Vault deployment name (StatefulSet or Deployment).
  -n    Kubernetes namespace where Vault is running.
        Default: current namespace '$NAMESPACE'.
  -h    Print script help.

Example:
  ./monitor-vault.sh \\
    -v my-vault \\
    -n my-vault
"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hv:n: flag; do
  case "${flag}" in
    v)
      VAULT_NAME=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Setup namespace argument for kubectl commands
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"

# Validate vault name is provided
if [ -z "$VAULT_NAME" ]; then
  echo -e "${COLOR_RED}Error: Vault deployment name is required. Use -v flag to specify the vault name.${COLOR_OFF}"
  print_help
  exit 1
fi

echo -e "${COLOR_BOLD}HashiCorp Vault HA Monitoring - Enhanced${COLOR_OFF}"
echo "=========================================="
echo

# Function to check if vault command is available in pods
check_vault_command() {
  local pod_name=$1
  kubectl exec $NAMESPACE_ARG "$pod_name" -- which vault >/dev/null 2>&1
}

# Function to get volume usage with improved logic
get_volume_usage() {
  local pvc_name=$1
  local namespace=$2
  local pod_name=$3
  
  # Try to get usage directly from the pod
  if [ -n "$pod_name" ]; then
    # Vault typically mounts data at /vault/data
    local mount_path="/vault/data"
    
    # Try to get disk usage from the pod
    local usage=$(kubectl exec -n "$namespace" "$pod_name" -- df -h "$mount_path" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
    
    if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
      echo "$usage"
    else
      # Try alternative mount point
      usage=$(kubectl exec -n "$namespace" "$pod_name" -- df -h /vault/file 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
      if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
        echo "$usage"
      else
        echo "Access denied"
      fi
    fi
  else
    echo "N/A"
  fi
}

# Function to get vault status from a pod
get_vault_status() {
  local pod_name=$1
  local vault_addr="http://127.0.0.1:8200"
  
  # Try to get vault status
  local status=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- vault status -address="$vault_addr" -format=json 2>/dev/null || echo "{}")
  echo "$status"
}

# Function to get vault leader info
get_vault_leader() {
  local pod_name=$1
  local vault_addr="http://127.0.0.1:8200"
  
  # Try to get leader info
  local leader=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- vault read -address="$vault_addr" -format=json sys/leader 2>/dev/null || echo "{}")
  echo "$leader"
}

# Get Vault pods using correct label selector
VAULT_PODS=$(kubectl get pods $NAMESPACE_ARG -l app.kubernetes.io/name=vault,component=server -o json 2>/dev/null)
if [ -z "$VAULT_PODS" ] || [ "$(echo "$VAULT_PODS" | jq -r '.items | length')" = "0" ]; then
  # Try alternative selector
  VAULT_PODS=$(kubectl get pods $NAMESPACE_ARG -l app=vault -o json 2>/dev/null)
  if [ -z "$VAULT_PODS" ] || [ "$(echo "$VAULT_PODS" | jq -r '.items | length')" = "0" ]; then
    # Try by name pattern
    VAULT_PODS=$(kubectl get pods $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$VAULT_NAME" '.items | map(select(.metadata.name | contains($name)))')
    if [ "$(echo "$VAULT_PODS" | jq -r 'length')" = "0" ]; then
      echo -e "${COLOR_RED}Error: No Vault pods found with name pattern '$VAULT_NAME'${COLOR_OFF}"
      exit 1
    fi
    # Reformat to match expected structure
    VAULT_PODS=$(echo '{"items":' "$VAULT_PODS" '}')
  fi
fi

# Extract basic info
TOTAL_PODS=$(echo "$VAULT_PODS" | jq -r '.items | length')
READY_PODS=$(echo "$VAULT_PODS" | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
RUNNING_PODS=$(echo "$VAULT_PODS" | jq -r '[.items[] | select(.status.phase=="Running")] | length')

echo -e "${COLOR_BOLD}Vault Cluster Summary${COLOR_OFF}"
echo -e "Deployment Name:     $VAULT_NAME"
echo -e "Namespace:           ${COLOR_BLUE}$NAMESPACE${COLOR_OFF}"
echo -e "Total Pods:          $TOTAL_PODS"

# Ready pods - green if all ready, yellow if partial, red if none
if [ "$READY_PODS" = "$TOTAL_PODS" ]; then
  echo -e "Ready Pods:          ${COLOR_GREEN}$READY_PODS${COLOR_OFF}"
elif [ "$READY_PODS" -gt 0 ]; then
  echo -e "Ready Pods:          ${COLOR_YELLOW}$READY_PODS${COLOR_OFF}"
else
  echo -e "Ready Pods:          ${COLOR_RED}$READY_PODS${COLOR_OFF}"
fi

# Running pods
if [ "$RUNNING_PODS" = "$TOTAL_PODS" ]; then
  echo -e "Running Pods:        ${COLOR_GREEN}$RUNNING_PODS${COLOR_OFF}"
elif [ "$RUNNING_PODS" -gt 0 ]; then
  echo -e "Running Pods:        ${COLOR_YELLOW}$RUNNING_PODS${COLOR_OFF}"
else
  echo -e "Running Pods:        ${COLOR_RED}$RUNNING_PODS${COLOR_OFF}"
fi
echo

# Function to get volume usage with improved logic
get_volume_usage() {
  local pvc_name=$1
  local namespace=$2
  local pod_name=$3
  
  # Try to get usage directly from the vault pod
  if [ -n "$pod_name" ]; then
    # Vault typically uses /vault/data for persistent storage
    local mount_path="/vault/data"
    
    # Try to get disk usage from the pod
    local usage=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- df -h "$mount_path" 2>/dev/null | tail -1 | awk '{print $2 "/" $1 " (" $4 " used)"}' 2>/dev/null)
    
    if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
      echo "$usage|$mount_path"
    else
      # Try alternative mount paths
      for alt_path in "/vault/file" "/opt/vault/data" "/opt/bitnami/vault/data" "/bitnami/vault/data" "/data"; do
        usage=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- df -h "$alt_path" 2>/dev/null | tail -1 | awk '{print $2 "/" $1 " (" $4 " used)"}' 2>/dev/null)
        if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
          echo "$usage|$alt_path"
          return
        fi
      done
      echo "Access denied|N/A"
    fi
  else
    echo "N/A|N/A"
  fi
}

# Storage Usage Analysis with consumption
echo -e "${COLOR_BOLD}Storage Usage Analysis${COLOR_OFF}"
VAULT_PVCS=$(kubectl get pvc $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$VAULT_NAME" '.items | map(select(.metadata.name | contains($name)))')

if [ "$(echo "$VAULT_PVCS" | jq -r 'length')" -gt 0 ]; then
  echo "$VAULT_PVCS" | jq -r '.[] | "\(.metadata.name)|\(.spec.resources.requests.storage)|\(.status.capacity.storage // "N/A")|\(.status.phase)"' | while IFS='|' read -r pvc_name requested actual phase; do
    # Find corresponding pod for this PVC
    pod_name=$(echo "$VAULT_PODS" | jq -r --arg pvc "$pvc_name" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | .metadata.name')
    usage_result=$(get_volume_usage "$pvc_name" "$NAMESPACE" "$pod_name")
    usage=$(echo "$usage_result" | cut -d'|' -f1)
    mount_path=$(echo "$usage_result" | cut -d'|' -f2)
    
    echo -e "PVC: ${COLOR_WHITE}$pvc_name${COLOR_OFF}"
    echo -e "  Pod: ${COLOR_WHITE}$pod_name${COLOR_OFF}"
    echo -e "  Requested: ${COLOR_WHITE}$requested${COLOR_OFF}"
    echo -e "  Actual: ${COLOR_WHITE}$actual${COLOR_OFF}"
    
    # Color code usage based on percentage - severity-based
    if [[ "$usage" == *"%"* ]]; then
      percentage=$(echo "$usage" | grep -o '[0-9]*%' | tr -d '%')
      if [ "$percentage" -gt 75 ]; then
        echo -e "  Usage: ${COLOR_RED}$usage${COLOR_OFF}"  # Critical
      elif [ "$percentage" -gt 50 ]; then
        echo -e "  Usage: ${COLOR_YELLOW}$usage${COLOR_OFF}"  # Warning
      else
        echo -e "  Usage: ${COLOR_GREEN}$usage${COLOR_OFF}"  # OK
      fi
    else
      echo -e "  Usage: ${COLOR_WHITE}$usage${COLOR_OFF}"
    fi
    
    if [ "$mount_path" != "N/A" ]; then
      echo -e "  Mount point: ${COLOR_WHITE}$mount_path${COLOR_OFF}"
    fi
    echo
  done
else
  echo "No persistent storage found (using emptyDir or no storage)"
  echo
fi

# Vault Services
echo -e "${COLOR_BOLD}Vault Services${COLOR_OFF}"
kubectl get svc $NAMESPACE_ARG -l app.kubernetes.io/name=vault -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
kubectl get svc $NAMESPACE_ARG -l app=vault -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
kubectl get svc $NAMESPACE_ARG -l app.kubernetes.io/component=vault -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
echo "No Vault services found"
echo

# Vault Status Analysis using pod labels
echo -e "${COLOR_BOLD}Vault Status Analysis${COLOR_OFF}"
printf "%-35s %-10s %-10s %-12s %-12s %-10s %-15s %s\n" "Pod Name" "Ready" "Active" "Sealed" "Initialized" "Standby" "Version" "Restarts"
printf "%-35s %-10s %-10s %-12s %-12s %-10s %-15s %s\n" "---------" "-----" "------" "------" "-----------" "-------" "-------" "--------"

LEADER_POD=""
INITIALIZED_COUNT=0
SEALED_COUNT=0
ACTIVE_COUNT=0

# Extract leader pod before the while loop to avoid subshell variable loss
LEADER_POD=$(echo "$VAULT_PODS" | jq -r '.items[] | select(.metadata.labels["vault-active"] == "true" or .metadata.labels["app.kubernetes.io/component"] == "server" and .metadata.labels["vault-active"] == "true") | .metadata.name')

echo "$VAULT_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.metadata.labels["vault-active"] // "unknown")|\(.metadata.labels["vault-sealed"] // "unknown")|\(.metadata.labels["vault-initialized"] // "unknown")|\(.metadata.labels["vault-perf-standby"] // "unknown")|\(.metadata.labels["vault-version"] // "N/A")|\(.status.containerStatuses[]? | select(.name=="vault" or .name=="vault-server" or .name=="bitnami-vault").ready // false)|\(.status.containerStatuses[]? | select(.name=="vault" or .name=="vault-server" or .name=="bitnami-vault").restartCount // 0)"' | while IFS='|' read -r pod_name is_active sealed initialized standby version ready_status restarts; do
  
  # Color coding
  ready_color="${COLOR_GREEN}"
  [ "$ready_status" != "true" ] && ready_color="${COLOR_RED}"
  
  active_color="${COLOR_BLUE}"
  [ "$is_active" = "true" ] && active_color="${COLOR_GREEN}"
  
  sealed_color="${COLOR_GREEN}"
  [ "$sealed" = "true" ] && sealed_color="${COLOR_RED}"
  
  init_color="${COLOR_GREEN}"
  [ "$initialized" = "false" ] && init_color="${COLOR_RED}"
  
  standby_color="${COLOR_BLUE}"
  [ "$standby" = "true" ] && standby_color="${COLOR_YELLOW}"
  
  restart_color="${COLOR_GREEN}"
  if [[ "$restarts" =~ ^[0-9]+$ ]]; then
    [ "$restarts" -gt 0 ] && restart_color="${COLOR_YELLOW}"
    [ "$restarts" -gt 5 ] && restart_color="${COLOR_RED}"
  fi
  
  printf "%-35s ${ready_color}%-10s${COLOR_OFF} %-10s %-12s %-12s %-10s %-15s ${restart_color}%s${COLOR_OFF}\n" \
    "$pod_name" "$ready_status" "$is_active" "$sealed" "$initialized" "$standby" "$version" "$restarts"
done || true

echo

# Pod Details
echo -e "${COLOR_BOLD}Pod Details${COLOR_OFF}"
echo "$VAULT_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.status.phase)|\(.status.podIP // "N/A")|\(.spec.nodeName // "N/A")|\(.status.containerStatuses[]? | select(.name=="vault" or .name=="vault-server" or .name=="bitnami-vault").restartCount // 0)"' | while IFS='|' read -r pod_name phase ip node restarts; do
  phase_color="${COLOR_GREEN}"
  [ "$phase" != "Running" ] && phase_color="${COLOR_RED}"
  
  restart_color="${COLOR_GREEN}"
  if [[ "$restarts" =~ ^[0-9]+$ ]]; then
    [ "$restarts" -gt 0 ] && restart_color="${COLOR_YELLOW}"
    [ "$restarts" -gt 5 ] && restart_color="${COLOR_RED}"
  fi
  
  echo -e "  ${COLOR_WHITE}$pod_name${COLOR_OFF}: Phase=${phase_color}$phase${COLOR_OFF}, IP=${COLOR_WHITE}$ip${COLOR_OFF}, Node=${COLOR_WHITE}$node${COLOR_OFF}, Restarts=${restart_color}$restarts${COLOR_OFF}"
done || true
echo

# Get recent events
echo -e "${COLOR_BOLD}Recent Vault Events${COLOR_OFF}"
vault_events=$(kubectl get events $NAMESPACE_ARG --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' 2>/dev/null | grep -i vault | tail -5)
if [ -n "$vault_events" ]; then
  echo "$vault_events"
else
  echo "No recent Vault events found"
fi
echo

# Health Check Summary
echo -e "${COLOR_BOLD}Health Check Summary${COLOR_OFF}"

if [ "$READY_PODS" = "$TOTAL_PODS" ]; then
  echo -e "  All pods ready: ${COLOR_GREEN}$READY_PODS/$TOTAL_PODS${COLOR_OFF}"
else
  echo -e "  Pods not ready: ${COLOR_RED}$READY_PODS/$TOTAL_PODS${COLOR_OFF}"
fi

if [ "$RUNNING_PODS" = "$TOTAL_PODS" ]; then
  echo -e "  All pods running: ${COLOR_GREEN}$RUNNING_PODS/$TOTAL_PODS${COLOR_OFF}"
else
  echo -e "  Pods not running: ${COLOR_RED}$RUNNING_PODS/$TOTAL_PODS${COLOR_OFF}"
fi
if [ -n "$LEADER_POD" ]; then
  echo -e "  Leader pod: ${COLOR_GREEN}$LEADER_POD${COLOR_OFF}"
else
  echo -e "  No leader pod identified: ${COLOR_RED}N/A${COLOR_OFF}"
fi

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
NAMESPACE="$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')"
REDIS_NAME=""

# Script helper
TEXT_HELPER="
This script aims to monitor Redis cluster deployment status and health.

Available flags:
  -r    Redis deployment name (StatefulSet or Deployment).
  -n    Kubernetes namespace where Redis is running.
        Default: current namespace '$NAMESPACE'.
  -h    Print script help.

Example:
  ./monitor-kube-redis.sh \\
    -r my-redis \\
    -n my-namespace
"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hr:n: flag; do
  case "${flag}" in
    r)
      REDIS_NAME=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Setup namespace argument for kubectl commands
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"

# Validate required parameters
if [ -z "$REDIS_NAME" ]; then
  echo -e "${COLOR_RED}Error: Redis deployment name is required. Use -r flag to specify the redis name.${COLOR_OFF}"
  print_help
  exit 1
fi

echo -e "${COLOR_BOLD}Redis Cluster Monitoring - Enhanced${COLOR_OFF}"
echo "==================================="
echo
echo

# Function to get volume usage with improved logic
get_volume_usage() {
  local pvc_name=$1
  local namespace=$2
  local pod_name=$3
  
  # Try to get usage directly from the redis pod
  if [ -n "$pod_name" ]; then
    # Redis typically uses /data for persistent storage
    local mount_path="/data"
    
    # Try to get disk usage from the pod
    local usage=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- df -h "$mount_path" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
    
    if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
      echo "$usage|$mount_path"
    else
      # Try alternative mount paths
      for alt_path in "/bitnami/redis/data" "/var/lib/redis" "/redis-data" "/usr/local/etc/redis"; do
        usage=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- df -h "$alt_path" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
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

# Get Redis pods
REDIS_PODS=$(kubectl get pods $NAMESPACE_ARG -o json 2>/dev/null)

if [ -z "$REDIS_PODS" ]; then
  echo "Error: Failed to get pods from namespace '$NAMESPACE'"
  exit 1
fi

# Filter pods by name
FILTERED_PODS=$(echo "$REDIS_PODS" | jq --arg name "$REDIS_NAME" '.items | map(select(.metadata.name | contains($name)))')

if [ "$(echo "$FILTERED_PODS" | jq -r 'length')" = "0" ]; then
  # Try with app label selector
  REDIS_PODS_BY_LABEL=$(kubectl get pods $NAMESPACE_ARG -l app="$REDIS_NAME" -o json 2>/dev/null)
  if [ -n "$REDIS_PODS_BY_LABEL" ] && [ "$(echo "$REDIS_PODS_BY_LABEL" | jq -r '.items | length')" -gt 0 ]; then
    FILTERED_PODS=$(echo "$REDIS_PODS_BY_LABEL" | jq '.items')
  else
    echo "Error: No Redis pods found for deployment '$REDIS_NAME' in namespace '$NAMESPACE'"
    exit 1
  fi
fi

# Use filtered pods for the rest of the script
REDIS_PODS=$(echo "$FILTERED_PODS" | jq -c '{items: .}')

# Get basic pod information
TOTAL_PODS=$(echo "$REDIS_PODS" | jq -r '.items | length')
READY_PODS=$(echo "$REDIS_PODS" | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
RUNNING_PODS=$(echo "$REDIS_PODS" | jq -r '[.items[] | select(.status.phase=="Running")] | length')

echo -e "Redis Cluster Summary"
echo -e "Deployment Name:     $REDIS_NAME"
echo -e "Namespace:           ${COLOR_BLUE}$NAMESPACE${COLOR_OFF}"
echo -e "Total Pods:          $TOTAL_PODS"

if [ "$READY_PODS" = "$TOTAL_PODS" ]; then
  echo -e "Ready Pods:          ${COLOR_GREEN}$READY_PODS${COLOR_OFF}"
elif [ "$READY_PODS" -gt 0 ]; then
  echo -e "Ready Pods:          ${COLOR_YELLOW}$READY_PODS${COLOR_OFF}"
else
  echo -e "Ready Pods:          ${COLOR_RED}$READY_PODS${COLOR_OFF}"
fi

if [ "$RUNNING_PODS" = "$TOTAL_PODS" ]; then
  echo -e "Running Pods:        ${COLOR_GREEN}$RUNNING_PODS${COLOR_OFF}"
elif [ "$RUNNING_PODS" -gt 0 ]; then
  echo -e "Running Pods:        ${COLOR_YELLOW}$RUNNING_PODS${COLOR_OFF}"
else
  echo -e "Running Pods:        ${COLOR_RED}$RUNNING_PODS${COLOR_OFF}"
fi
echo

# Storage Usage Analysis with consumption
echo -e "${COLOR_BOLD}Storage Usage Analysis${COLOR_OFF}"
REDIS_PVCS=$(kubectl get pvc $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$REDIS_NAME" '.items | map(select(.metadata.name | contains($name)))')

if [ "$(echo "$REDIS_PVCS" | jq -r 'length')" -gt 0 ]; then
  echo "$REDIS_PVCS" | jq -r '.[] | "\(.metadata.name)|\(.spec.resources.requests.storage)|\(.status.capacity.storage // "N/A")|\(.status.phase)"' | while IFS='|' read -r pvc_name requested actual phase; do
    # Find corresponding pod for this PVC
    pod_name=$(echo "$REDIS_PODS" | jq -r --arg pvc "$pvc_name" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | .metadata.name')
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

# Redis Services
echo -e "${COLOR_BOLD}Redis Services${COLOR_OFF}"
redis_services=$(kubectl get svc $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$REDIS_NAME" -r '.items[] | select(.metadata.name | contains($name)) | "\(.metadata.name)|\(.spec.type)|\(.spec.clusterIP)|\(.status.loadBalancer.ingress[0].ip // "<none>")|\(.spec.ports | map(.port) | join(","))"')

if [ -n "$redis_services" ]; then
  printf "%-30s %-12s %-15s %-13s %s\n" "NAME" "TYPE" "CLUSTER-IP" "EXTERNAL-IP" "PORT(S)"
  echo "$redis_services" | while IFS='|' read -r name type cluster_ip external_ip ports; do
    printf "%-30s %-12s %-15s %-13s %s\n" "$name" "$type" "$cluster_ip" "$external_ip" "$ports"
  done
else
  echo "No Redis services found"
fi
echo

# Redis Status Analysis using pod labels and exec commands
echo -e "${COLOR_BOLD}Redis Status Analysis${COLOR_OFF}"
printf "%-35s %-10s %-10s %-15s %-12s %-15s %s\n" "Pod Name" "Ready" "Role" "Replication" "Memory" "Version" "Restarts"
printf "%-35s %-10s %-10s %-15s %-12s %-15s %s\n" "--------" "-----" "----" "-----------" "------" "-------" "--------"

# Extract master pod before the while loop to avoid subshell variable loss
MASTER_POD=$(echo "$REDIS_PODS" | jq -r '.items[] | select(.metadata.labels["app.kubernetes.io/component"] == "master" or .metadata.labels["role"] == "master" or (.metadata.name | contains("master"))) | .metadata.name')

echo "$REDIS_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.metadata.labels["app.kubernetes.io/component"] // "unknown")|\(.metadata.labels["role"] // "unknown")|\(.status.containerStatuses[]? | select(.name=="redis" or .name=="redis-server" or .name=="bitnami-redis").ready // false)|\(.status.containerStatuses[]? | select(.name=="redis" or .name=="redis-server" or .name=="bitnami-redis").restartCount // 0)"' | while IFS='|' read -r pod_name component role ready_status restarts; do
  
  # Determine Redis role
  redis_role="unknown"
  if [[ "$component" == "master" ]] || [[ "$role" == "master" ]] || [[ "$pod_name" == *"master"* ]]; then
    redis_role="master"
  elif [[ "$component" == "replica" ]] || [[ "$role" == "replica" ]] || [[ "$pod_name" == *"replica"* ]] || [[ "$pod_name" == *"slave"* ]]; then
    redis_role="replica"
  fi
  
  # Try to get Redis info via redis-cli
  replication_info="N/A"
  memory_info="N/A"
  version_info="N/A"
  
  # Try to execute redis-cli commands
  if [ "$ready_status" = "true" ]; then
    # Try with different redis-cli paths and authentication
    for cli_cmd in "redis-cli" "/usr/local/bin/redis-cli" "/usr/bin/redis-cli" "/opt/bitnami/redis/bin/redis-cli"; do
      # Get replication info
      repl_result=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- $cli_cmd --no-auth-warning info replication 2>/dev/null | grep "role:" | cut -d: -f2 | tr -d '\r' 2>/dev/null || echo "")
      if [ -n "$repl_result" ]; then
        replication_info="$repl_result"
        # Get memory usage
        memory_result=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- $cli_cmd --no-auth-warning info memory 2>/dev/null | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r' 2>/dev/null || echo "N/A")
        [ -n "$memory_result" ] && memory_info="$memory_result"
        # Get version
        version_result=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- $cli_cmd --no-auth-warning info server 2>/dev/null | grep "redis_version:" | cut -d: -f2 | tr -d '\r' 2>/dev/null || echo "N/A")
        [ -n "$version_result" ] && version_info="$version_result"
        break
      fi
    done
  fi
  
  # Color coding
  ready_color="${COLOR_GREEN}"
  [ "$ready_status" != "true" ] && ready_color="${COLOR_RED}"
  
  restart_color="${COLOR_GREEN}"
  if [[ "$restarts" =~ ^[0-9]+$ ]]; then
    [ "$restarts" -gt 0 ] && restart_color="${COLOR_YELLOW}"
    [ "$restarts" -gt 5 ] && restart_color="${COLOR_RED}"
  fi
  
  printf "%-35s ${ready_color}%-10s${COLOR_OFF} %-10s %-15s %-12s %-15s ${restart_color}%s${COLOR_OFF}\n" \
    "$pod_name" "$ready_status" "$redis_role" "$replication_info" "$memory_info" "$version_info" "$restarts"
done || true

echo

# Pod Details
echo -e "${COLOR_BOLD}Pod Details${COLOR_OFF}"
echo "$REDIS_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.status.phase)|\(.status.podIP // "N/A")|\(.spec.nodeName // "N/A")|\(.status.containerStatuses[]? | select(.name=="redis" or .name=="redis-server" or .name=="bitnami-redis").restartCount // 0)"' | while IFS='|' read -r pod_name phase ip node restarts; do
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
echo -e "${COLOR_BOLD}Recent Redis Events${COLOR_OFF}"
redis_events=$(kubectl get events $NAMESPACE_ARG --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' 2>/dev/null | grep -i redis | tail -5)
if [ -n "$redis_events" ]; then
  echo "$redis_events"
else
  echo "No recent Redis events found"
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

if [ -n "$MASTER_POD" ]; then
  echo -e "  Master pod: ${COLOR_GREEN}$MASTER_POD${COLOR_OFF}"
else
  echo -e "  No master pod identified: ${COLOR_RED}N/A${COLOR_OFF}"
fi

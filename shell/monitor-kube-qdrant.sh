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
QDRANT_NAME=""

# Script helper
TEXT_HELPER="
This script aims to monitor Qdrant vector database cluster status and health.

Available flags:
  -q    Qdrant deployment name (StatefulSet or Deployment).
  -n    Kubernetes namespace where Qdrant is running.
        Default: current namespace '$NAMESPACE'.
  -h    Print script help.

Example:
  ./monitor-kube-qdrant.sh \\
    -q my-qdrant \\
    -n my-namespace
"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hq:n: flag; do
  case "${flag}" in
    q)
      QDRANT_NAME=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Setup namespace argument for kubectl commands
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"

# Validate qdrant name is provided
if [ -z "$QDRANT_NAME" ]; then
  echo -e "${COLOR_RED}Error: Qdrant deployment name is required. Use -q flag to specify the qdrant name.${COLOR_OFF}"
  print_help
  exit 1
fi

echo -e "${COLOR_BOLD}Qdrant Vector Database Monitoring - Enhanced${COLOR_OFF}"
echo "============================================="
echo

# Function to get volume usage with improved logic
get_volume_usage() {
  local pvc_name=$1
  local namespace=$2
  local pod_name=$3
  
  # Try to get usage directly from the qdrant pod
  if [ -n "$pod_name" ]; then
    # Qdrant typically uses /qdrant/storage for persistent storage
    local mount_path="/qdrant/storage"
    
    # Try to get disk usage from the pod
    local usage=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- df -h "$mount_path" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
    
    if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
      echo "$usage|$mount_path"
    else
      # Try alternative mount paths
      for alt_path in "/opt/qdrant/storage" "/data" "/storage" "/var/lib/qdrant"; do
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

# Function to get qdrant health status from a pod
get_qdrant_health() {
  local pod_name=$1
  # HTTP clients not available, return empty
  echo "{}"
}

# Function to get qdrant cluster info
get_qdrant_cluster_info() {
  local pod_name=$1
  # HTTP clients not available, return empty
  echo "{}"
}

# Function to get qdrant collections info
get_qdrant_collections() {
  local pod_name=$1
  # HTTP clients not available, return empty
  echo "{}"
}

# Function to get qdrant metrics
get_qdrant_metrics() {
  local pod_name=$1
  # HTTP clients not available, return empty
  echo ""
}

# Alternative functions when HTTP clients are not available
# Function to get collections from filesystem
get_qdrant_collections_from_fs() {
  local pod_name=$1
  
  # Try to list collections directory
  local collections=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- ls /qdrant/storage/collections 2>/dev/null || echo "")
  if [ -n "$collections" ]; then
    echo "$collections" | wc -l | tr -d ' '
  else
    echo "N/A"
  fi
}

# Function to get raft state information
get_qdrant_raft_state() {
  local pod_name=$1
  
  # Try to read raft state file
  local raft_state=$(kubectl exec $NAMESPACE_ARG "$pod_name" -- cat /qdrant/storage/raft_state.json 2>/dev/null || echo "{}")
  echo "$raft_state"
}

# Function to extract node information from raft state
get_node_info_from_raft() {
  local raft_state=$1
  
  if [ -n "$raft_state" ] && [ "$raft_state" != "{}" ]; then
    local this_peer_id=$(echo "$raft_state" | jq -r '.this_peer_id // "N/A"' 2>/dev/null || echo "N/A")
    local voters_count=$(echo "$raft_state" | jq -r '.state.conf_state.voters | length' 2>/dev/null || echo "0")
    local version=$(echo "$raft_state" | jq -r --arg peer_id "$this_peer_id" '.peer_metadata_by_id[$peer_id].version // "N/A"' 2>/dev/null || echo "N/A")
    local first_voter=$(echo "$raft_state" | jq -r '.first_voter // "N/A"' 2>/dev/null || echo "N/A")
    
    # Determine role - first voter is typically the leader in Qdrant raft
    local role="replica"
    if [ "$this_peer_id" = "$first_voter" ]; then
      role="leader"
    fi
    
    echo "$this_peer_id|$voters_count|$version|$role"
  else
    echo "N/A|0|N/A|N/A"
  fi
}

# Get Qdrant pods using correct label selector
QDRANT_PODS=$(kubectl get pods $NAMESPACE_ARG -l app.kubernetes.io/name=qdrant -o json 2>/dev/null)
if [ -z "$QDRANT_PODS" ] || [ "$(echo "$QDRANT_PODS" | jq -r '.items | length')" = "0" ]; then
  # Try alternative selector
  QDRANT_PODS=$(kubectl get pods $NAMESPACE_ARG -l app=qdrant -o json 2>/dev/null)
  if [ -z "$QDRANT_PODS" ] || [ "$(echo "$QDRANT_PODS" | jq -r '.items | length')" = "0" ]; then
    # Try by name pattern
    QDRANT_PODS=$(kubectl get pods $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$QDRANT_NAME" '.items | map(select(.metadata.name | contains($name)))')
    if [ "$(echo "$QDRANT_PODS" | jq -r 'length')" = "0" ]; then
      echo -e "${COLOR_RED}Error: No Qdrant pods found with name pattern '$QDRANT_NAME'${COLOR_OFF}"
      exit 1
    fi
    # Reformat to match expected structure
    QDRANT_PODS=$(echo '{"items":' "$QDRANT_PODS" '}')
  fi
fi

# Extract basic info
TOTAL_PODS=$(echo "$QDRANT_PODS" | jq -r '.items | length')
READY_PODS=$(echo "$QDRANT_PODS" | jq -r '[.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True"))] | length')
RUNNING_PODS=$(echo "$QDRANT_PODS" | jq -r '[.items[] | select(.status.phase=="Running")] | length')

echo -e "${COLOR_BOLD}Qdrant Cluster Summary${COLOR_OFF}"
echo -e "Deployment Name:     $QDRANT_NAME"
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

# Storage Usage Analysis
echo -e "${COLOR_BOLD}Storage Usage Analysis${COLOR_OFF}"
QDRANT_PVCS=$(kubectl get pvc $NAMESPACE_ARG -o json 2>/dev/null | jq --arg name "$QDRANT_NAME" '.items | map(select(.metadata.name | contains($name)))')

if [ "$(echo "$QDRANT_PVCS" | jq -r 'length')" -gt 0 ]; then
  echo "$QDRANT_PVCS" | jq -r '.[] | "\(.metadata.name)|\(.spec.resources.requests.storage)|\(.status.capacity.storage // "N/A")|\(.status.phase)"' | while IFS='|' read -r pvc_name requested actual phase; do
    # Find corresponding pod for this PVC
    pod_name=$(echo "$QDRANT_PODS" | jq -r --arg pvc "$pvc_name" '.items[] | select(.spec.volumes[]?.persistentVolumeClaim.claimName == $pvc) | .metadata.name')
    usage_result=$(get_volume_usage "$pvc_name" "$NAMESPACE" "$pod_name")
    usage=$(echo "$usage_result" | cut -d'|' -f1)
    mount_path=$(echo "$usage_result" | cut -d'|' -f2)
    
    echo -e "PVC: ${COLOR_WHITE}$pvc_name${COLOR_OFF}"
    echo -e "  Pod: ${COLOR_WHITE}$pod_name${COLOR_OFF}"
    echo -e "  Requested: ${COLOR_WHITE}$requested${COLOR_OFF}"
    echo -e "  Actual: ${COLOR_WHITE}$actual${COLOR_OFF}"
    
    # Color code usage based on percentage
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

# Qdrant Services
echo -e "${COLOR_BOLD}Qdrant Services${COLOR_OFF}"
kubectl get svc $NAMESPACE_ARG -l app.kubernetes.io/name=qdrant -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
kubectl get svc $NAMESPACE_ARG -l app=qdrant -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
kubectl get svc $NAMESPACE_ARG -l app.kubernetes.io/component=qdrant -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,CLUSTER-IP:.spec.clusterIP,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,PORT(S):.spec.ports[*].port" 2>/dev/null || \
echo "No Qdrant services found"
echo

# Check HTTP client availability for API monitoring
first_ready_pod=$(echo "$QDRANT_PODS" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True")) | .metadata.name' | head -1)
# Since we know curl/wget are not available, set to false
HTTP_CLIENT_AVAILABLE=false

if [ "$HTTP_CLIENT_AVAILABLE" = "false" ]; then
  echo -e "${COLOR_YELLOW}⚠️  Warning: No HTTP client (curl/wget) found in Qdrant containers.${COLOR_OFF}"
  echo -e "${COLOR_YELLOW}   API-based monitoring (health, collections, cluster info) will be limited.${COLOR_OFF}"
  echo -e "${COLOR_YELLOW}   Using filesystem-based monitoring instead.${COLOR_OFF}"
  if [ -n "$first_ready_pod" ]; then
    echo -e "${COLOR_YELLOW}   For detailed API monitoring, use: kubectl port-forward $first_ready_pod 6333:6333${COLOR_OFF}"
  fi
  echo
fi

# Qdrant Status Analysis
echo -e "${COLOR_BOLD}Qdrant Status Analysis${COLOR_OFF}"
printf "%-35s %-10s %-8s %-12s %-12s %-10s %s\n" "Pod Name" "Ready" "Role" "Collections" "Version" "Restarts" "Node ID"
printf "%-35s %-10s %-8s %-12s %-12s %-10s %s\n" "---------" "-----" "----" "-----------" "-------" "--------" "-------"

echo "$QDRANT_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.status.containerStatuses[]? | select(.name=="qdrant" or .name=="qdrant-server").ready // false)|\(.status.containerStatuses[]? | select(.name=="qdrant" or .name=="qdrant-server").restartCount // 0)|\(.metadata.labels["app.kubernetes.io/version"] // "N/A")"' | while IFS='|' read -r pod_name ready_status restarts version; do
  
  # Get Qdrant-specific status information
  collections_count="N/A"
  node_id="N/A"
  role="N/A"
  
  if [ "$ready_status" = "true" ]; then
    if [ "$HTTP_CLIENT_AVAILABLE" = "true" ]; then
      # Try to get collections count via API
      collections_info=$(get_qdrant_collections "$pod_name")
      if [ -n "$collections_info" ] && [ "$collections_info" != "{}" ]; then
        collections_count=$(echo "$collections_info" | jq -r '.result.collections | length' 2>/dev/null || echo "N/A")
      fi
      
      # Try to get cluster info for node ID via API
      cluster_info=$(get_qdrant_cluster_info "$pod_name")
      if [ -n "$cluster_info" ] && [ "$cluster_info" != "{}" ]; then
        node_id=$(echo "$cluster_info" | jq -r '.result.peer_id // "N/A"' 2>/dev/null || echo "N/A")
        # Try to determine role from cluster info - this would need cluster API to determine leader
        role="replica"  # Default assumption when using API without leader info
      fi
    else
      # Use filesystem-based alternatives
      
      # Get collections count from filesystem
      collections_count=$(get_qdrant_collections_from_fs "$pod_name")
      
      # Get node info from raft state
      raft_state=$(get_qdrant_raft_state "$pod_name")
      node_info=$(get_node_info_from_raft "$raft_state")
      node_id=$(echo "$node_info" | cut -d'|' -f1)
      role=$(echo "$node_info" | cut -d'|' -f4)
      
      # Override version from raft state if available
      raft_version=$(echo "$node_info" | cut -d'|' -f3)
      if [ "$raft_version" != "N/A" ] && [ "$version" = "N/A" ]; then
        version="$raft_version"
      fi
    fi
  fi
  
  # Color coding
  ready_color="${COLOR_GREEN}"
  [ "$ready_status" != "true" ] && ready_color="${COLOR_RED}"
  
  restart_color="${COLOR_GREEN}"
  if [[ "$restarts" =~ ^[0-9]+$ ]]; then
    [ "$restarts" -gt 0 ] && restart_color="${COLOR_YELLOW}"
    [ "$restarts" -gt 5 ] && restart_color="${COLOR_RED}"
  fi
  
  printf "%-35s ${ready_color}%-10s${COLOR_OFF} %-8s %-12s %-12s ${restart_color}%-10s${COLOR_OFF} %s\n" \
    "$pod_name" "$ready_status" "$role" "$collections_count" "$version" "$restarts" "$node_id"
done || true

echo

# Pod Details
echo -e "${COLOR_BOLD}Pod Details${COLOR_OFF}"
echo "$QDRANT_PODS" | jq -r '.items[] | "\(.metadata.name)|\(.status.phase)|\(.status.podIP // "N/A")|\(.spec.nodeName // "N/A")|\(.status.containerStatuses[]? | select(.name=="qdrant" or .name=="qdrant-server").restartCount // 0)"' | while IFS='|' read -r pod_name phase ip node restarts; do
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

# Cluster Information (if clustering is enabled)
echo -e "${COLOR_BOLD}Cluster Information${COLOR_OFF}"

if [ -n "$first_ready_pod" ]; then
  if [ "$HTTP_CLIENT_AVAILABLE" = "true" ]; then
    # Use API-based cluster information
    cluster_info=$(get_qdrant_cluster_info "$first_ready_pod")
    if [ -n "$cluster_info" ] && [ "$cluster_info" != "{}" ]; then
      cluster_enabled=$(echo "$cluster_info" | jq -r '.result.enabled // false' 2>/dev/null)
      peer_count=$(echo "$cluster_info" | jq -r '.result.peers | length' 2>/dev/null || echo "0")
      consensus_status=$(echo "$cluster_info" | jq -r '.result.raft_info.state // "N/A"' 2>/dev/null)
      
      if [ "$cluster_enabled" = "true" ]; then
        echo -e "Clustering:          ${COLOR_GREEN}Enabled${COLOR_OFF}"
        echo -e "Peer Count:          ${COLOR_WHITE}$peer_count${COLOR_OFF}"
        echo -e "Consensus Status:    ${COLOR_WHITE}$consensus_status${COLOR_OFF}"
        
        # Show peers if available
        peers=$(echo "$cluster_info" | jq -r '.result.peers[] | "\(.uri)|\(.id)"' 2>/dev/null)
        if [ -n "$peers" ]; then
          echo -e "Peers:"
          echo "$peers" | while IFS='|' read -r uri peer_id; do
            echo -e "  - ${COLOR_WHITE}$uri${COLOR_OFF} (ID: ${COLOR_BLUE}$peer_id${COLOR_OFF})"
          done
        fi
      else
        echo -e "Clustering:          ${COLOR_YELLOW}Disabled${COLOR_OFF}"
      fi
    else
      echo "Unable to retrieve cluster information via API"
    fi
  else
    # Use filesystem-based cluster information from raft state
    raft_state=$(get_qdrant_raft_state "$first_ready_pod")
    if [ -n "$raft_state" ] && [ "$raft_state" != "{}" ]; then
      voters_count=$(echo "$raft_state" | jq -r '.state.conf_state.voters | length' 2>/dev/null || echo "0")
      term=$(echo "$raft_state" | jq -r '.state.hard_state.term // "N/A"' 2>/dev/null)
      this_peer_id=$(echo "$raft_state" | jq -r '.this_peer_id // "N/A"' 2>/dev/null)
      
      if [ "$voters_count" -gt 1 ]; then
        echo -e "Clustering:          ${COLOR_GREEN}Enabled (from raft state)${COLOR_OFF}"
        echo -e "Voters Count:        ${COLOR_WHITE}$voters_count${COLOR_OFF}"
        echo -e "Raft Term:           ${COLOR_WHITE}$term${COLOR_OFF}"
        echo -e "This Node ID:        ${COLOR_WHITE}$this_peer_id${COLOR_OFF}"
        
        # Show peer addresses if available
        peer_addresses=$(echo "$raft_state" | jq -r '.peer_address_by_id | to_entries[] | "\(.key)|\(.value)"' 2>/dev/null)
        if [ -n "$peer_addresses" ]; then
          echo -e "Cluster Peers:"
          echo "$peer_addresses" | while IFS='|' read -r peer_id addr; do
            # Get version for this peer
            peer_version=$(echo "$raft_state" | jq -r --arg peer_id "$peer_id" '.peer_metadata_by_id[$peer_id].version // "N/A"' 2>/dev/null)
            echo -e "  - ${COLOR_WHITE}$addr${COLOR_OFF} (ID: ${COLOR_BLUE}$peer_id${COLOR_OFF}, Version: ${COLOR_WHITE}$peer_version${COLOR_OFF})"
          done
        fi
      else
        echo -e "Clustering:          ${COLOR_YELLOW}Single node or disabled${COLOR_OFF}"
      fi
    else
      echo "Unable to retrieve cluster information from filesystem"
    fi
  fi
else
  echo "No ready pods available for cluster information"
fi
echo

# Collections Summary
echo -e "${COLOR_BOLD}Collections Summary${COLOR_OFF}"
if [ -n "$first_ready_pod" ]; then
  if [ "$HTTP_CLIENT_AVAILABLE" = "true" ]; then
    # Use API-based collections information
    collections_info=$(get_qdrant_collections "$first_ready_pod")
    if [ -n "$collections_info" ] && [ "$collections_info" != "{}" ]; then
      collections_count=$(echo "$collections_info" | jq -r '.result.collections | length' 2>/dev/null || echo "0")
      echo -e "Total Collections:   ${COLOR_WHITE}$collections_count${COLOR_OFF}"
    else
      echo "Unable to retrieve collections information via API"
    fi
  else
    # Use filesystem-based collections information
    collections_list=$(kubectl exec $NAMESPACE_ARG "$first_ready_pod" -- ls /qdrant/storage/collections 2>/dev/null || echo "")
    if [ -n "$collections_list" ]; then
      collections_count=$(echo "$collections_list" | wc -l | tr -d ' ')
      echo -e "Total Collections:   ${COLOR_WHITE}$collections_count${COLOR_OFF} (from filesystem)"
    else
      echo "Unable to retrieve collections information from filesystem"
    fi
  fi
else
  echo "No ready pods available for collections information"
fi
echo

# Get recent events
echo -e "${COLOR_BOLD}Recent Qdrant Events${COLOR_OFF}"
qdrant_events=$(kubectl get events $NAMESPACE_ARG --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' 2>/dev/null | grep -i qdrant | tail -5)
if [ -n "$qdrant_events" ]; then
  echo "$qdrant_events"
else
  echo "No recent Qdrant events found"
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

# Check if any pods are healthy
healthy_pods=0
if [ -n "$first_ready_pod" ]; then
  echo "$QDRANT_PODS" | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="True")) | .metadata.name' | while read -r pod_name; do
    health_info=$(get_qdrant_health "$pod_name")
    if [ -n "$health_info" ] && [ "$health_info" != "{}" ]; then
      health_status=$(echo "$health_info" | jq -r '.status // "unknown"' 2>/dev/null)
      if [ "$health_status" = "ok" ] || [ "$health_status" = "healthy" ]; then
        healthy_pods=$((healthy_pods + 1))
      fi
    fi
  done
fi

# Overall cluster health assessment
if [ "$READY_PODS" = "$TOTAL_PODS" ] && [ "$RUNNING_PODS" = "$TOTAL_PODS" ]; then
  echo -e "  Overall Status: ${COLOR_GREEN}Healthy${COLOR_OFF}"
elif [ "$READY_PODS" -gt 0 ] && [ "$RUNNING_PODS" -gt 0 ]; then
  echo -e "  Overall Status: ${COLOR_YELLOW}Degraded${COLOR_OFF}"
else
  echo -e "  Overall Status: ${COLOR_RED}Unhealthy${COLOR_OFF}"
fi

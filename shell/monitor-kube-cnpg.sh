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
CLUSTER_NAME=""
NAMESPACE_ARG=""

# Script helper
TEXT_HELPER="
This script aims to monitor CloudNativePG cluster status and replication.

Available flags:
  -c    CloudNativePG cluster name.
  -n    Kubernetes namespace where the cluster is running.
        Default: current namespace '$NAMESPACE'.
  -h    Print script help.

Example:
  ./monitor-cnpg.sh \\
    -c my-cluster \\
    -n my-namespace
"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:n: flag; do
  case "${flag}" in
    c)
      CLUSTER_NAME=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Setup namespace argument for kubectl commands
[[ ! -z "$NAMESPACE" ]] && NAMESPACE_ARG="--namespace=$NAMESPACE"

# Validate cluster name is provided
if [ -z "$CLUSTER_NAME" ]; then
  echo -e "${COLOR_RED}Error: Cluster name is required. Use -c flag to specify the cluster name.${COLOR_OFF}"
  print_help
  exit 1
fi

echo -e "${COLOR_BOLD}CloudNativePG Cluster Monitoring - Enhanced${COLOR_OFF}"
echo "=============================================="
echo

# Get cluster info
CLUSTER_INFO=$(kubectl get clusters.postgresql.cnpg.io $CLUSTER_NAME $NAMESPACE_ARG -o json 2>/dev/null)

if [ -z "$CLUSTER_INFO" ]; then
  echo -e "${COLOR_RED}Error: Cluster '$CLUSTER_NAME' not found${COLOR_OFF}"
  exit 1
fi

# Extract cluster details
NAMESPACE=$(echo "$CLUSTER_INFO" | jq -r '.metadata.namespace')
PG_IMAGE=$(echo "$CLUSTER_INFO" | jq -r '.status.image')
PRIMARY_INSTANCE=$(echo "$CLUSTER_INFO" | jq -r '.status.currentPrimary')
PRIMARY_START_TIME=$(echo "$CLUSTER_INFO" | jq -r '.status.currentPrimaryTimestamp')
CLUSTER_STATUS=$(echo "$CLUSTER_INFO" | jq -r '.status.phase')
INSTANCES_TOTAL=$(echo "$CLUSTER_INFO" | jq -r '.spec.instances')
INSTANCES_READY=$(echo "$CLUSTER_INFO" | jq -r '.status.readyInstances')
DATA_STORAGE=$(echo "$CLUSTER_INFO" | jq -r '.spec.storage.size')
WAL_STORAGE=$(echo "$CLUSTER_INFO" | jq -r '.spec.walStorage.size // "N/A"')

# Calculate uptime
if [ "$PRIMARY_START_TIME" != "null" ] && [ "$PRIMARY_START_TIME" != "" ]; then
  UPTIME_SECONDS=$(( $(date +%s) - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${PRIMARY_START_TIME%.*}Z" +%s 2>/dev/null || echo "0") ))
  UPTIME_HOURS=$((UPTIME_SECONDS / 3600))
  UPTIME_MINUTES=$(((UPTIME_SECONDS % 3600) / 60))
  UPTIME="${UPTIME_HOURS}h${UPTIME_MINUTES}m"
else
  UPTIME="N/A"
fi

echo -e "${COLOR_BOLD}Cluster Summary${COLOR_OFF}"
echo -e "Name                 $CLUSTER_NAME"
echo -e "Namespace            ${COLOR_BLUE}$NAMESPACE${COLOR_OFF}"
echo -e "PostgreSQL Image:    $PG_IMAGE"
echo -e "Primary instance:    ${COLOR_YELLOW}$PRIMARY_INSTANCE${COLOR_OFF}"
echo -e "Primary start time:  $PRIMARY_START_TIME (uptime ${COLOR_GREEN}$UPTIME${COLOR_OFF})"
# Status color based on health
if [ "$CLUSTER_STATUS" = "Cluster in healthy state" ]; then
  echo -e "Status:              ${COLOR_GREEN}$CLUSTER_STATUS${COLOR_OFF}"
else
  echo -e "Status:              ${COLOR_RED}$CLUSTER_STATUS${COLOR_OFF}"
fi
echo -e "Instances:           $INSTANCES_TOTAL"
# Ready instances - green if all ready, yellow if partial, red if none
if [ "$INSTANCES_READY" = "$INSTANCES_TOTAL" ]; then
  echo -e "Ready instances:     ${COLOR_GREEN}$INSTANCES_READY${COLOR_OFF}"
elif [ "$INSTANCES_READY" -gt 0 ]; then
  echo -e "Ready instances:     ${COLOR_YELLOW}$INSTANCES_READY${COLOR_OFF}"
else
  echo -e "Ready instances:     ${COLOR_RED}$INSTANCES_READY${COLOR_OFF}"
fi
echo -e "Data Storage Size:   ${COLOR_BLUE}$DATA_STORAGE${COLOR_OFF}"
echo -e "WAL Storage Size:    ${COLOR_BLUE}$WAL_STORAGE${COLOR_OFF}"
echo

# Function to get volume usage with improved logic
get_volume_usage() {
  local pvc_name=$1
  local namespace=$2
  local instance_name=$3
  
  # Try to get usage directly from the instance pod
  if [ -n "$instance_name" ]; then
    # Determine mount path based on PVC type
    if [[ "$pvc_name" == *"-wal" ]]; then
      mount_path="/var/lib/postgresql/wal"
    else
      mount_path="/var/lib/postgresql/data"
    fi
    
    # Try to get disk usage from the pod
    local usage=$(kubectl exec -n "$namespace" "$instance_name" -c postgres -- df -h "$mount_path" 2>/dev/null | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null)
    
    if [ -n "$usage" ] && [[ "$usage" != *"N/A"* ]]; then
      echo "$usage|$mount_path"
    else
      echo "Access denied|$mount_path"
    fi
  else
    echo "N/A|N/A"
  fi
}

# Storage Usage Analysis with consumption
echo -e "${COLOR_BOLD}Storage Usage Analysis${COLOR_OFF}"
PVCS=$(kubectl get pvc $NAMESPACE_ARG -l cnpg.io/cluster="$CLUSTER_NAME" -o json)

echo "$PVCS" | jq -r '.items[] | "\(.metadata.name)|\(.spec.resources.requests.storage)|\(.status.capacity.storage // "N/A")|\(.metadata.labels["cnpg.io/instanceName"] // "N/A")"' | while IFS='|' read -r pvc_name requested actual instance; do
  usage_result=$(get_volume_usage "$pvc_name" "$NAMESPACE" "$instance")
  usage=$(echo "$usage_result" | cut -d'|' -f1)
  mount_path=$(echo "$usage_result" | cut -d'|' -f2)
  
  echo -e "PVC: ${COLOR_WHITE}$pvc_name${COLOR_OFF}"
  echo -e "  Instance: ${COLOR_WHITE}$instance${COLOR_OFF}"
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

# Function to get LSN from a pod
get_lsn() {
  local pod_name=$1
  local namespace=$2
  local role=$3
  
  # Use different functions for primary vs replica
  if [ "$role" = "primary" ]; then
    # Primary: get current WAL LSN
    local lsn=$(kubectl exec -n "$namespace" "$pod_name" -c postgres -- psql -U postgres -t -c "SELECT pg_current_wal_lsn();" 2>/dev/null | tr -d ' \n')
  else
    # Replica: get last received LSN
    local lsn=$(kubectl exec -n "$namespace" "$pod_name" -c postgres -- psql -U postgres -t -c "SELECT pg_last_wal_receive_lsn();" 2>/dev/null | tr -d ' \n')
  fi
  
  if [ -z "$lsn" ] || [ "$lsn" = "" ]; then
    echo "N/A"
  else
    echo "$lsn"
  fi
}

# Function to get detailed replication info for a specific replica
get_replica_sync_mode() {
  local primary_pod=$1
  local replica_name=$2
  local namespace=$3
  
  # Query pg_stat_replication for this specific replica
  local sync_info=$(kubectl exec -n "$namespace" "$primary_pod" -c postgres -- psql -U postgres -t -c "
    SELECT 
      CASE 
        WHEN sync_state = 'sync' THEN 'Synchronous'
        WHEN sync_state = 'async' THEN 'Streaming'
        WHEN sync_state = 'potential' THEN 'Potential Sync'
        ELSE 'File-based'
      END as repl_mode
    FROM pg_stat_replication 
    WHERE application_name = '$replica_name'
    LIMIT 1;
  " 2>/dev/null | tr -d ' \n')
  
  if [ -n "$sync_info" ] && [ "$sync_info" != "" ]; then
    echo "$sync_info"
  else
    echo "File-based"
  fi
}

# Backup information
echo -e "${COLOR_BOLD}Physical backups${COLOR_OFF}"
BARMAN_BACKUP=$(echo "$CLUSTER_INFO" | jq -r '.status.lastSuccessfulBackup // "N/A"')
echo "Backup via barman:              $BARMAN_BACKUP"
echo

# Get current write LSN and WAL file info from primary
echo -e "${COLOR_BOLD}Current WAL Status${COLOR_OFF}"
if [ -n "$PRIMARY_INSTANCE" ]; then
  CURRENT_LSN=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "SELECT pg_current_wal_lsn();" 2>/dev/null | tr -d ' \n')
  TIMELINE_ID=$(echo "$CLUSTER_INFO" | jq -r '.status.timelineID // "N/A"')
  
  if [ -n "$CURRENT_LSN" ] && [ "$CURRENT_LSN" != "" ]; then
    # Calculate WAL file name from LSN
    WAL_FILE=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "SELECT pg_walfile_name('$CURRENT_LSN');" 2>/dev/null | tr -d ' \n')
    echo -e "Current Write LSN:   ${COLOR_GREEN}$CURRENT_LSN${COLOR_OFF} (Timeline: ${COLOR_YELLOW}$TIMELINE_ID${COLOR_OFF} - WAL File: ${COLOR_BLUE}$WAL_FILE${COLOR_OFF})"
  else
    echo -e "Current Write LSN:   ${COLOR_RED}N/A${COLOR_OFF} (Timeline: $TIMELINE_ID - WAL File: N/A)"
  fi
else
  echo "Current Write LSN:   N/A (Timeline: N/A - WAL File: N/A)"
fi
echo

# Continuous Backup status
echo -e "${COLOR_BOLD}Continuous Backup status${COLOR_OFF}"
BACKUP_STATUS=$(echo "$CLUSTER_INFO" | jq -r '.status.firstRecoverabilityPoint // "N/A"')
LAST_BACKUP=$(echo "$CLUSTER_INFO" | jq -r '.status.lastSuccessfulBackup // "N/A"')
BACKUP_RETENTION=$(echo "$CLUSTER_INFO" | jq -r '.spec.backup.retentionPolicy // "N/A"')

if [ "$BACKUP_STATUS" = "N/A" ] || [ "$BACKUP_STATUS" = "null" ]; then
  echo -e "${COLOR_RED}Not configured${COLOR_OFF}"
else
  echo -e "First Point of Recoverability:  ${COLOR_GREEN}$BACKUP_STATUS${COLOR_OFF}"
  echo -e "Last successful backup:         ${COLOR_GREEN}$LAST_BACKUP${COLOR_OFF}"
  echo -e "Backup retention policy:        ${COLOR_BLUE}$BACKUP_RETENTION${COLOR_OFF}"
fi
echo

# Streaming Replication status
echo -e "${COLOR_BOLD}Streaming Replication status${COLOR_OFF}"
MAX_SYNC_REPLICAS=$(echo "$CLUSTER_INFO" | jq -r '.spec.postgresql.syncReplicaElectionConstraint.enabled // false')
MIN_SYNC_REPLICAS=$(echo "$CLUSTER_INFO" | jq -r '.spec.minSyncReplicas // 0')

# Check if replication slots are enabled
REPLICATION_SLOTS=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "SELECT count(*) FROM pg_replication_slots;" 2>/dev/null | tr -d ' \n')
if [ -n "$REPLICATION_SLOTS" ] && [ "$REPLICATION_SLOTS" != "0" ]; then
  echo -e "${COLOR_GREEN}Replication Slots Enabled${COLOR_OFF}"
else
  echo -e "${COLOR_RED}Replication Slots Disabled${COLOR_OFF}"
fi

# Display detailed replication information
printf "%-23s %-12s %-12s %-12s %-12s %-10s %-10s %-11s %-10s %-11s %-14s %s\n" "Name" "Sent LSN" "Write LSN" "Flush LSN" "Replay LSN" "Write Lag" "Flush Lag" "Replay Lag" "State" "Sync State" "Sync Priority" "Replication Slot"
printf "%-23s %-12s %-12s %-12s %-12s %-10s %-10s %-11s %-10s %-11s %-14s %s\n" "----" "--------" "---------" "---------" "----------" "---------" "---------" "----------" "-----" "----------" "-------------" "----------------"

if [ -n "$PRIMARY_INSTANCE" ]; then
  kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "
    SELECT 
      application_name || '|' ||
      sent_lsn || '|' ||
      write_lsn || '|' ||
      flush_lsn || '|' ||
      replay_lsn || '|' ||
      COALESCE(write_lag, '00:00:00'::interval) || '|' ||
      COALESCE(flush_lag, '00:00:00'::interval) || '|' ||
      COALESCE(replay_lag, '00:00:00'::interval) || '|' ||
      state || '|' ||
      sync_state || '|' ||
      sync_priority
    FROM pg_stat_replication 
    ORDER BY application_name;
  " 2>/dev/null | while IFS='|' read -r app_name sent_lsn write_lsn flush_lsn replay_lsn write_lag flush_lag replay_lag state sync_state sync_priority; do
    if [ -n "$app_name" ] && [ "$app_name" != "" ]; then
      # Clean up any whitespace
      app_name=$(echo "$app_name" | tr -d ' ')
      sent_lsn=$(echo "$sent_lsn" | tr -d ' ')
      write_lsn=$(echo "$write_lsn" | tr -d ' ')
      flush_lsn=$(echo "$flush_lsn" | tr -d ' ')
      replay_lsn=$(echo "$replay_lsn" | tr -d ' ')
      write_lag=$(echo "$write_lag" | tr -d ' ')
      flush_lag=$(echo "$flush_lag" | tr -d ' ')
      replay_lag=$(echo "$replay_lag" | tr -d ' ')
      state=$(echo "$state" | tr -d ' ')
      sync_state=$(echo "$sync_state" | tr -d ' ')
      sync_priority=$(echo "$sync_priority" | tr -d ' ')
      
      # Check if replication slot is active
      slot_status=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "SELECT CASE WHEN active THEN 'active' ELSE 'inactive' END FROM pg_replication_slots WHERE slot_name = '$app_name';" 2>/dev/null | tr -d ' \n')
      [ -z "$slot_status" ] && slot_status="N/A"
      
      # Color code lag times - but not in printf
      lag_color=""
      if [ "$write_lag" = "00:00:00" ] && [ "$flush_lag" = "00:00:00" ] && [ "$replay_lag" = "00:00:00" ]; then
        lag_color="${COLOR_GREEN}"
      else
        lag_color="${COLOR_YELLOW}"
      fi
      
      # Color code sync state
      sync_color=""
      if [ "$sync_state" = "sync" ]; then
        sync_color="${COLOR_GREEN}"
      else
        sync_color="${COLOR_BLUE}"
      fi
      
      # Color code slot status
      slot_color=""
      if [ "$slot_status" = "active" ]; then
        slot_color="${COLOR_GREEN}"
      elif [ "$slot_status" = "inactive" ]; then
        slot_color="${COLOR_RED}"
      fi
      
      printf "%-23s %-12s %-12s %-12s %-12s %-10s %-10s %-11s %-10s %-11s %-14s %s\n" \
        "$app_name" "$sent_lsn" "$write_lsn" "$flush_lsn" "$replay_lsn" \
        "$write_lag" \
        "$flush_lag" \
        "$replay_lag" \
        "$state" \
        "$sync_state" \
        "$sync_priority" \
        "$slot_status"
    fi
  done
fi

echo

echo -e "${COLOR_BOLD}Instance Details${COLOR_OFF}"
kubectl get pods $NAMESPACE_ARG -l cnpg.io/cluster="$CLUSTER_NAME" -o json | jq -r '.items[] | 
  "\(.metadata.name)|\(.metadata.labels["cnpg.io/instanceRole"] // "unknown")|\(.status.phase)|\(.status.podIP // "N/A")"
' | while IFS='|' read -r pod_name role status ip; do
  is_primary="false"
  if [ "$pod_name" = "$PRIMARY_INSTANCE" ]; then
    is_primary="true"
  fi
  echo -e "  ${COLOR_WHITE}$pod_name${COLOR_OFF}: Primary=${COLOR_GREEN}$is_primary${COLOR_OFF}, Timeline=${COLOR_WHITE}$TIMELINE_ID${COLOR_OFF}, IP=${COLOR_WHITE}$ip${COLOR_OFF}"
done
echo

# Instances status with enhanced replication info
echo -e "${COLOR_BOLD}Instances status${COLOR_OFF}"
printf "%-33s %-12s %-17s %-7s %-10s %-15s %s\n" "Name" "Current LSN" "Replication role" "Status" "QoS" "Manager Version" "Node"
printf "%-33s %-12s %-17s %-7s %-10s %-15s %s\n" "----" "-----------" "----------------" "------" "---" "---------------" "----"

kubectl get pods $NAMESPACE_ARG -l cnpg.io/cluster="$CLUSTER_NAME" -o json | jq -r '.items[] | 
  "\(.metadata.name)|\(.metadata.labels["cnpg.io/instanceRole"] // "unknown")|\(.status.phase)|\(.status.qosClass // "N/A")|\(.spec.containers[0].image | split(":")[1])|\(.spec.nodeName // "N/A")"
' | while IFS='|' read -r pod_name role status qos version node; do
  lsn=$(get_lsn "$pod_name" "$NAMESPACE" "$role")
  
  # Format role like cnpg plugin
  if [ "$role" = "primary" ]; then
    formatted_role="Primary"
    role_color="${COLOR_GREEN}"
    formatted_status="OK"
    status_color="${COLOR_GREEN}"
  else
    # Check if it's sync or async
    sync_mode=$(get_replica_sync_mode "$PRIMARY_INSTANCE" "$pod_name" "$NAMESPACE")
    if [ "$sync_mode" = "Synchronous" ]; then
      formatted_role="Standby (sync)"
      role_color="${COLOR_YELLOW}"  # Warning level for sync
    else
      formatted_role="Standby (async)"
      role_color="${COLOR_WHITE}"   # Info level for async
    fi
    formatted_status="OK"
    status_color="${COLOR_GREEN}"
  fi
  
  # Use simplified status
  [ "$status" = "Running" ] && formatted_status="OK" && status_color="${COLOR_GREEN}"
  
  printf "%-33s %-12s %-17s %-7s %-10s %-15s %s\n" \
    "$pod_name" "$lsn" \
    "$formatted_role" \
    "$formatted_status" \
    "$qos" "$version" "$node"
done

echo
echo "Note: LSN retrieval uses pg_current_wal_lsn() for primary and pg_last_wal_receive_lsn() for replicas."
echo "      Replication lag times show write, flush, and replay delays between primary and replicas."
echo

# Determine overall replication mode
OVERALL_REPL_MODE="Unknown"
if [ -n "$PRIMARY_INSTANCE" ]; then
  # Check if we have any replicas
  REPLICA_COUNT=$(kubectl get pods $NAMESPACE_ARG -l cnpg.io/cluster="$CLUSTER_NAME" -o json | jq -r '[.items[] | select(.metadata.labels["cnpg.io/instanceRole"] != "primary")] | length')
  
  if [ "$REPLICA_COUNT" = "0" ]; then
    OVERALL_REPL_MODE="No replicas"
  else
    # Check if any replica is synchronous
    SYNC_REPLICAS=$(kubectl exec -n "$NAMESPACE" "$PRIMARY_INSTANCE" -c postgres -- psql -U postgres -t -c "SELECT count(*) FROM pg_stat_replication WHERE sync_state = 'sync';" 2>/dev/null | tr -d ' \n')
    
    if [ -n "$SYNC_REPLICAS" ] && [ "$SYNC_REPLICAS" != "0" ]; then
      OVERALL_REPL_MODE="Mixed (sync+async)"
    else
      OVERALL_REPL_MODE="Async streaming"
    fi
  fi
fi

# Recent cluster events
echo -e "${COLOR_BOLD}Recent cluster events${COLOR_OFF}"
kubectl get events $NAMESPACE_ARG --field-selector involvedObject.name="$CLUSTER_NAME" --sort-by='.lastTimestamp' | tail -5
echo

# Health Check Summary
echo -e "${COLOR_BOLD}Health Check Summary${COLOR_OFF}"
if [ "$INSTANCES_READY" = "$INSTANCES_TOTAL" ]; then
  echo -e "  All instances ready: ${COLOR_GREEN}$INSTANCES_READY/$INSTANCES_TOTAL${COLOR_OFF}"
else
  echo -e "  Instances not ready: ${COLOR_RED}$INSTANCES_READY/$INSTANCES_TOTAL${COLOR_OFF}"
fi

if [ "$LAST_BACKUP" != "N/A" ] && [ "$LAST_BACKUP" != "null" ]; then
  echo -e "  Backup status: ${COLOR_GREEN}Working${COLOR_OFF}"
else
  echo -e "  Backup status: ${COLOR_RED}Issues detected${COLOR_OFF}"
fi

echo -e "  Replication: $OVERALL_REPL_MODE"

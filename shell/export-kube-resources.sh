#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
EXPORT_DIR="./kube-export"

# Script helper
TEXT_HELPER="
This script aims to export ready-to-apply kubernetes resources.
It uses kubectl-neat to clean up manifests metadata and jq to process kubernetes resources so it is required to install these cli to work correctly.

Available flags:
  -k    Kind of resources to export.
  -n    Kubernetes namespace target to copy kubernetes resources.
        Default: all namespaces.
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'
  -h    Print script help.

Example:
  ./export-kube-resources.sh \\
    -k 'all' \\
    -n 'default' \\
    -o './kube-export'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

export_kube_resources () {
  EXPORT_FILE="$EXPORT_DIR/$1.yaml"
  # Clear existing content in the projects file
  > "$EXPORT_FILE"

  if [ ! -z "$NAMESPACE" ]; then
    KUBECTL_ARGS="-n $NAMESPACE"
  else
    KUBECTL_ARGS="-A"
  fi

  RESOURCES=$(kubectl get $1 --no-headers -o json $KUBECTL_ARGS | jq -r '.items[] | "\(.metadata.name),\(.metadata.namespace)"')

  while IFS=',' read -r name namespace; do
    printf "Export ${COLOR_RED}$1/$name${COLOR_OFF} from namespace ${COLOR_RED}$namespace${COLOR_OFF}.\n"
    echo "---" >> "$EXPORT_FILE"
    kubectl get $1 $name -n $namespace -o yaml | kubectl neat >> "$EXPORT_FILE"
    echo "" >> "$EXPORT_FILE"
  done <<< "$RESOURCES"
}

# Parse options
while getopts hk:n:o: flag; do
  case "${flag}" in
    k)
      RESOURCES_KIND=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    o)
      EXPORT_DIR=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > RESOURCES_KIND: ${RESOURCES_KIND}
  > NAMESPACE: ${NAMESPACE:-all}
  > EXPORT_DIR: ${EXPORT_DIR}
"

# Init
mkdir -p "$EXPORT_DIR"

if [ -z "$RESOURCES_KIND" ]; then
  printf "Wrong arguments, you need to specify a valid kind of resources.\n"
  print_help
  exit 1
else 
  export_kube_resources "$RESOURCES_KIND"
fi

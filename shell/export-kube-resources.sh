#!/bin/bash

set -euo pipefail

# Exports can contain Secrets: keep the files and the export directory private
umask 077

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Defaults
EXPORT_DIR="./kube-export"
NAMESPACE=""
RESOURCES_KIND=""

# Script helper
TEXT_HELPER="
This script aims to export ready-to-apply kubernetes resources.
It uses kubectl-neat to clean up manifests metadata and jq to process kubernetes resources so it is required to install these cli to work correctly.
Exported files are only readable by their owner since they can contain secrets.

Available flags:
  -k    Kind of resources to export ('all', a kind, or a comma-separated list of kinds).
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
  local KUBECTL_ARGS RESOURCES resource name namespace
  EXPORT_FILE="$EXPORT_DIR/$1.yaml"
  # Clear existing content in the projects file
  : > "$EXPORT_FILE"

  if [ -n "$NAMESPACE" ]; then
    KUBECTL_ARGS="--namespace=$NAMESPACE"
  else
    KUBECTL_ARGS="--all-namespaces"
  fi

  # Fetch each item by its own kind and group: '-k all' or a list of kinds returns several kinds,
  # and cluster-scoped items have no namespace.
  RESOURCES=$(kubectl get "$1" -o json "$KUBECTL_ARGS" | jq -r '.items[] | [
      ((.kind | ascii_downcase) + (if (.apiVersion | contains("/")) then "." + (.apiVersion | split("/")[0]) else "" end)),
      .metadata.name,
      (.metadata.namespace // "")
    ] | @tsv')

  while IFS=$'\t' read -r resource name namespace; do
    [ -n "$name" ] || continue
    printf "Export ${COLOR_RED}%s/%s${COLOR_OFF} from namespace ${COLOR_RED}%s${COLOR_OFF}.\n" "$resource" "$name" "${namespace:-<cluster>}"
    echo "---" >> "$EXPORT_FILE"
    if [ -n "$namespace" ]; then
      kubectl get "$resource" "$name" --namespace="$namespace" -o yaml | kubectl neat >> "$EXPORT_FILE"
    else
      kubectl get "$resource" "$name" -o yaml | kubectl neat >> "$EXPORT_FILE"
    fi
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
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Settings
printf "
Settings:
  > RESOURCES_KIND: ${RESOURCES_KIND}
  > NAMESPACE: ${NAMESPACE:-all}
  > EXPORT_DIR: ${EXPORT_DIR}
"

if [ -z "$RESOURCES_KIND" ]; then
  printf "Wrong arguments, you need to specify a valid kind of resources.\n" >&2
  print_help >&2
  exit 1
fi
if ! command -v kubectl-neat >/dev/null 2>&1; then
  printf "Error: the kubectl-neat plugin is required (https://github.com/itaysk/kubectl-neat).\n" >&2
  exit 1
fi

# Init
mkdir -p "$EXPORT_DIR"
export_kube_resources "$RESOURCES_KIND"

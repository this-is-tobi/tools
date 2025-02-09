#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
EXPORT_DIR="./kube-export"

# Declare script helper
TEXT_HELPER="\nThis script aims to export ready-to-apply kubernetes resources.
It uses kubectl-neat to clean up manifests metadata and jq to process kubernetes resources so it is required to install these cli to work correctly.
Following flags are available:

  -k    Kind of resources to export.

  -n    Kubernetes namespace target to copy kubernetes resources.
        Default is all namespaces.

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
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


mkdir -p "$EXPORT_DIR"

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
    printf "Export ${red}$1/$name${no_color} from namespace ${red}$namespace${no_color}.\n"
    echo "---" >> "$EXPORT_FILE"
    kubectl get $1 $name -n $namespace -o yaml | kubectl neat >> "$EXPORT_FILE"
    echo "" >> "$EXPORT_FILE"
  done <<< "$RESOURCES"
}

if [ -z "$RESOURCES_KIND" ]; then
  printf "Wrong arguments, you need to specify a valid kind of resources.\n"
  print_help
  exit 1
else 
  export_kube_resources "$RESOURCES_KIND"
fi

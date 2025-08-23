#!/bin/bash

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
RESOURCES_KIND="all"
NAMESPACE="argocd"
EXPORT_DIR="./argocd-export"

# Script helper
TEXT_HELPER="
This script aims to export ready-to-apply argocd projects, applications and applicationsets.
It uses kubectl-neat to clean up manifests metadata so it is required to work correctly.

Available flags:
  -k    Kind of resources to export, available kinds are 'apps', 'appsets', 'projects' and 'all'.
        Default: '$RESOURCES_KIND'.
  -n    Kubernetes namespace target to copy argocd resources.
        Default: '$NAMESPACE'
  -o    Output directory where to export files.
        Default: '$EXPORT_DIR'
  -h    Print script help.

Example:
  ./export-argocd-resources.sh \\
    -k 'all' \\
    -n 'argocd' \\
    -o './argocd-export'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

export_argocd_resources () {
  EXPORT_FILE="$EXPORT_DIR/$1.yaml"
  # Clear existing content in the projects file
  > "$EXPORT_FILE"

  RESOURCES=$(kubectl get $1 -n $NAMESPACE --no-headers -o custom-columns=":metadata.name")

  for RESOURCE in $RESOURCES; do
    echo "---" >> "$EXPORT_FILE"
    kubectl get $1 $RESOURCE -n $NAMESPACE -o yaml | kubectl neat >> "$EXPORT_FILE"
    echo "" >> "$EXPORT_FILE"
  done
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
  > NAMESPACE: ${NAMESPACE}
  > EXPORT_DIR: ${EXPORT_DIR}
"

# Init
mkdir -p "$EXPORT_DIR"

if [[ "$RESOURCES_KIND" == "projects" ]]; then
  export_argocd_resources appprojects
elif [[ "$RESOURCES_KIND" == "apps" ]]; then 
  export_argocd_resources apps
elif [[ "$RESOURCES_KIND" == "appsets" ]]; then 
  export_argocd_resources appsets
elif [[ "$RESOURCES_KIND" == "all" ]]; then 
  export_argocd_resources appprojects
  export_argocd_resources apps
  export_argocd_resources appsets
else
  printf "Wrong arguments, you need to specify a valid kind of resources.\n"
  print_help
  exit 1
fi

#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
RESOURCES_KIND="all"
NAMESPACE="argocd"
EXPORT_DIR="./argocd-export"

# Declare script helper
TEXT_HELPER="\nThis script aims to export ready-to-apply argocd projects, applications and applicationsets.
It uses kubectl-neat to clean up manifests metadata so it is required to work correctly.
Following flags are available:

  -k    Kind of resources to export, available kinds are 'apps', 'appsets', 'projects' and 'all'.
        Default is '$RESOURCES_KIND'.

  -n    Kubernetes namespace target to copy argocd resources.
        Default is '$NAMESPACE'

  -o    Output directory where to export files.
        Default is '$EXPORT_DIR'

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts k:n:o:h flag; do
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

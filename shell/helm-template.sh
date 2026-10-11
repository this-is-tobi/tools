#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Defaults
# The chart template comes from the helm-charts repository: main by default, set HELM_CHARTS_REF to
# a branch, tag or commit SHA to pin it, or HELM_CHARTS_REPO to clone another location.
HELM_CHARTS_REPO="${HELM_CHARTS_REPO:-https://github.com/this-is-tobi/helm-charts}"
HELM_CHARTS_REF="${HELM_CHARTS_REF:-main}"
CHART_NAME="my-awesome-chart"
OUTPUT_DIR="$(pwd)/$CHART_NAME"
ADDITIONAL_SERVICE_NAMES=()
SERVICE_NAME=""
WORK_DIR=""

# Script helper
TEXT_HELPER="
This script aims to create a generic Helm chart.

Available flags:
  -a  Helm additional service name. You can specify multiple additional services by using this flag multiple times.
      Default: empty list.
  -c  Helm chart name.
      Default: '$CHART_NAME'.
  -o  Output directory to generate Helm chart files.
      Default: '$OUTPUT_DIR' ('\$(pwd)/<chart_name>').
  -s  Helm base service name.
  -h  Print script help.

Service names become '.Values.<name>' paths in the templates, so keep them to letters and digits.

The template is cloned from '$HELM_CHARTS_REPO' at '$HELM_CHARTS_REF'.
Set HELM_CHARTS_REF=<branch|tag|sha> to pin it, HELM_CHARTS_REPO=<url> to use another repository.

Example:
  ./helm-template.sh \\
    -c 'my-awesome-chart' \\
    -s 'api' \\
    -a 'worker' \\
    -a 'client' \\
    -o './my-awesome-chart'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

cleanup () {
  local STATUS=$?
  if [ -n "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
  fi
  exit "$STATUS"
}

# Fetches the template once, at HELM_CHARTS_REF, into a temporary directory
fetchTemplate () {
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Clone the template chart ('%s' at '%s')\n\n" "$HELM_CHARTS_REPO" "$HELM_CHARTS_REF"
  WORK_DIR="$(mktemp -d)"
  git -C "$WORK_DIR" init --quiet
  git -C "$WORK_DIR" fetch --quiet --depth 1 "$HELM_CHARTS_REPO" "$HELM_CHARTS_REF"
  git -C "$WORK_DIR" -c advice.detachedHead=false checkout --quiet FETCH_HEAD
  TEMPLATE_DIR="$WORK_DIR/template"
  if [ ! -f "$TEMPLATE_DIR/Chart.yaml" ] || [ ! -d "$TEMPLATE_DIR/templates/servicename" ]; then
    printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: no chart template found in '%s' at '%s'.\n" "$HELM_CHARTS_REPO" "$HELM_CHARTS_REF" >&2
    exit 1
  fi
}

capitalize () {
  printf '%s' "$(echo "$1" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "$1" | cut -c2-)"
}

# Parse options
while getopts ha:c:o:s: flag; do
  case "${flag}" in
    a)
      ADDITIONAL_SERVICE_NAMES+=("${OPTARG}");;
    c)
      CHART_NAME="${OPTARG}"
      OUTPUT_DIR="$(pwd)/$CHART_NAME";;
    o)
      OUTPUT_DIR="${OPTARG}";;
    s)
      SERVICE_NAME="${OPTARG}";;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

trap cleanup EXIT

# Settings
printf "
Settings:
  > CHART_NAME: ${CHART_NAME}
  > OUTPUT_DIR: ${OUTPUT_DIR}
  > SERVICE_NAME: ${SERVICE_NAME}
  > ADDITIONAL_SERVICE_NAMES: ${ADDITIONAL_SERVICE_NAMES[*]:-}
  > HELM_CHARTS_REF: ${HELM_CHARTS_REF}
"

# Options validation
if ! command -v git >/dev/null 2>&1; then
  printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'git' is required but not installed.\n" >&2
  exit 1
fi
if ! command -v yq >/dev/null 2>&1; then
  printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'yq' is required but not installed.\n" >&2
  exit 1
fi
if [ "$(uname -s)" = "Darwin" ]; then
  if ! command -v gsed >/dev/null 2>&1; then
    printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'gsed' is required but not installed.\n" >&2
    printf "Please install GNU sed with 'brew install gnu-sed' and try again.\n\n" >&2
    exit 1
  fi
  SED_COMMAND="gsed"
else
  SED_COMMAND="sed"
fi

if [ -n "$SERVICE_NAME" ] || [ ${#ADDITIONAL_SERVICE_NAMES[@]} -gt 0 ]; then
  fetchTemplate
fi

# Handle base service
if [ -n "$SERVICE_NAME" ]; then
  # Copy the template chart, dotfiles included
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Copy the template chart\n\n"
  mkdir -p "$OUTPUT_DIR"
  cp -R "$TEMPLATE_DIR/." "$OUTPUT_DIR/"

  # Rename the chart
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'Chart.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" "$OUTPUT_DIR/Chart.yaml"

  # Rename templates directory
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename templates directory\n\n"
  mv "$OUTPUT_DIR/templates/servicename" "$OUTPUT_DIR/templates/${SERVICE_NAME}"

  # Update service name in template files
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in templates files\n\n"
  find "$OUTPUT_DIR/templates/${SERVICE_NAME}" -type f -exec ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" "$OUTPUT_DIR/values.yaml" {} +

  # Update service name in values file
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in 'values.yaml' file\n\n"
  SERVICE_NAME_CAPITALIZED="$(capitalize "$SERVICE_NAME")"
  NAME="$SERVICE_NAME" yq eval '.[strenv(NAME)] = .servicename | del(.servicename)' -i "$OUTPUT_DIR/values.yaml"
  ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" "$OUTPUT_DIR/values.yaml"
  ${SED_COMMAND} -i "s/Servicename/${SERVICE_NAME_CAPITALIZED}/g" "$OUTPUT_DIR/values.yaml"

  # Update chart name in values
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" "$OUTPUT_DIR/values.yaml"
fi


# Handle additional services
for ADDITIONAL_SERVICE_NAME in ${ADDITIONAL_SERVICE_NAMES[@]+"${ADDITIONAL_SERVICE_NAMES[@]}"}; do
  # Copy additional service templates
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Copy additional service\n\n"
  mkdir -p "$OUTPUT_DIR/templates/${ADDITIONAL_SERVICE_NAME}"
  cp -R "$TEMPLATE_DIR/templates/servicename/." "$OUTPUT_DIR/templates/${ADDITIONAL_SERVICE_NAME}/"

  # Update service name in template files
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in templates files\n\n"
  find "$OUTPUT_DIR/templates/${ADDITIONAL_SERVICE_NAME}" -type f -exec ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" "$OUTPUT_DIR/values.yaml" {} +

  # Update service name in values file
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in 'values.yaml' file\n\n"
  ADDITIONAL_SERVICE_NAME_CAPITALIZED="$(capitalize "$ADDITIONAL_SERVICE_NAME")"
  NAME="$ADDITIONAL_SERVICE_NAME" TEMPLATE_VALUES="$TEMPLATE_DIR/values.yaml" \
    yq eval '.[strenv(NAME)] = load(strenv(TEMPLATE_VALUES)).servicename' -i "$OUTPUT_DIR/values.yaml"
  ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" "$OUTPUT_DIR/values.yaml"
  ${SED_COMMAND} -i "s/Servicename/${ADDITIONAL_SERVICE_NAME_CAPITALIZED}/g" "$OUTPUT_DIR/values.yaml"

  # Update chart name in values
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" "$OUTPUT_DIR/values.yaml"
done

# Update chart readme file
if [ -n "$SERVICE_NAME" ] || [ ${#ADDITIONAL_SERVICE_NAMES[@]} -gt 0 ]; then
  if command -v helm-docs >/dev/null 2>&1; then
    printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Update 'readme.md' file\n\n"
    helm-docs -u -c "$OUTPUT_DIR"
  else
    printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Warning: 'helm-docs' is not installed. Skipping readme update.\n"
  fi
fi

#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
CHART_NAME="my-awesome-chart"
OUTPUT_DIR="$(pwd)/$CHART_NAME"
ADDITIONAL_SERVICE_NAMES=()

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

Example:
  ./helm-template.sh \\
    -c 'my-awesome-chart' \\
    -s 'api-1' \\
    -a 'api-2' \\
    -a 'client' \\
    -o './my-awesome-chart'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
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
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > CHART_NAME: ${CHART_NAME}
  > OUTPUT_DIR: ${OUTPUT_DIR}
  > SERVICE_NAME: ${SERVICE_NAME}
  > ADDITIONAL_SERVICE_NAMES: ${ADDITIONAL_SERVICE_NAMES[@]}
"

# Options validation
if [ ! -x "$(command -v curl)" ]; then
  printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'curl' is required but not installed.\n"
  exit 1
fi
if [ ! -x "$(command -v yq)" ]; then
  printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'yq' is required but not installed.\n"
  exit 1
fi
if [ "$(uname -s)" = "Darwin" ]; then
  if [ ! -x $(command -v gsed) ]; then
    printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Error: 'gsed' is required but not installed.\n"
    printf "Please install GNU sed with 'brew install gnu-sed' and try again.\n\n"
    exit 1
  fi
  SED_COMMAND="gsed"
else
  SED_COMMAND="sed"
fi

# Handle base service
if [ -n "$SERVICE_NAME" ]; then
  # Create tmp directory
  mkdir -p ${OUTPUT_DIR}/tmp

  # Clone the template chart
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Clone the template chart\n\n"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template" \
    -o "${OUTPUT_DIR}" \
    -d
  mv ${OUTPUT_DIR}/template/* ${OUTPUT_DIR}
  rm -rf ${OUTPUT_DIR}/template

  # Rename the chart
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'Chart.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" ${OUTPUT_DIR}/Chart.yaml

  # Rename templates directory
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename templates directory\n\n"
  mv ${OUTPUT_DIR}/templates/servicename ${OUTPUT_DIR}/templates/${SERVICE_NAME}

  # Update service name in template files
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in templates files\n\n"
  find ${OUTPUT_DIR}/templates/${SERVICE_NAME} -type f -exec ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml {} \;

  # Update service name in values file
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in 'values.yaml' file\n\n"
  SERVICE_NAME_CAPITALIZED="$(echo "$SERVICE_NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "$SERVICE_NAME" | cut -c2-)"
  yq eval ".${SERVICE_NAME} = .servicename | del(.servicename)" -i ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/Servicename/${SERVICE_NAME_CAPITALIZED}/g" ${OUTPUT_DIR}/values.yaml

  # Update chart name in values
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Delete tmp directory
  rm -rf ${OUTPUT_DIR}/tmp
fi


# Handle additional services
for ADDITIONAL_SERVICE_NAME in "${ADDITIONAL_SERVICE_NAMES[@]}"; do
  # Create tmp directory
  mkdir -p ${OUTPUT_DIR}/tmp

  # Clone additional service
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Clone additional service\n\n"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template/templates/servicename" \
    -o "${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}" \
    -d
  mv ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/servicename/* ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}
  rm -rf ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/template
  rm -rf ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/servicename

  # Update service name in template files
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in templates files\n\n"
  find ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME} -type f -exec ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml {} \;

  # Update service name in values file
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename service in 'values.yaml' file\n\n"
  ADDITIONAL_SERVICE_NAME_CAPITALIZED="$(echo "$ADDITIONAL_SERVICE_NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "$ADDITIONAL_SERVICE_NAME" | cut -c2-)"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template/values.yaml" \
    -o "${OUTPUT_DIR}/tmp" \
    -d
  yq eval ".${ADDITIONAL_SERVICE_NAME} = load(\"${OUTPUT_DIR}/tmp/values.yaml\").servicename" -i ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/Servicename/${ADDITIONAL_SERVICE_NAME_CAPITALIZED}/g" ${OUTPUT_DIR}/values.yaml

  # Update chart name in values
  printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Delete tmp directory
  rm -rf ${OUTPUT_DIR}/tmp
done

# Update chart readme file
if [ -n "$SERVICE_NAME" ] || [ ${#ADDITIONAL_SERVICE_NAMES[@]} -gt 0 ]; then
  if [ -x "$(command -v helm-docs)" ]; then
    printf "\n\n${COLOR_RED}[helm template]${COLOR_OFF} Update 'readme.md' file\n\n"
    helm-docs -u ${OUTPUT_DIR}
  else
    printf "\n${COLOR_RED}[helm template]${COLOR_OFF} Warning: 'helm-docs' is not installed. Skipping readme update.\n"
  fi
fi

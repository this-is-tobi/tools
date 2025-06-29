#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'


# Defaults
CHART_NAME="my-awesome-chart"
OUTPUT_DIR="$(pwd)/$CHART_NAME"

# Declare script helper
TEXT_HELPER="\nThis script aims to create a generic Helm chart.

Following flags are available:

  -a  Helm additional service name.

  -c  Helm chart name.
      Default is '$CHART_NAME'.

  -o  Output directory to generate Helm chart files.
      Default is '$OUTPUT_DIR' ('\$(pwd)/<chart_name>').

  -s  Helm base service name.

  -h  Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts ha:c:o:s: flag; do
  case "${flag}" in
    a)
      ADDITIONAL_SERVICE_NAME="${OPTARG}";;
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


if [ "$(uname -s)" = "Darwin" ]; then
  SED_COMMAND="gsed"
else
  SED_COMMAND="sed"
fi


if [ -n "$SERVICE_NAME" ]; then
  # Create tmp directory
  mkdir -p ${OUTPUT_DIR}/tmp

  # Clone the template chart
  printf "\n\n${red}[helm template]${no_color} Clone the template chart\n\n"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template" \
    -o "${OUTPUT_DIR}" \
    -d
  mv ${OUTPUT_DIR}/template/* ${OUTPUT_DIR}
  rm -rf ${OUTPUT_DIR}/template

  # Rename the chart
  printf "\n\n${red}[helm template]${no_color} Rename chart in 'Chart.yaml' file\n\n"
  CHART_NAME_CAPITALIZED="$(echo "$CHART_NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')$(echo "$CHART_NAME" | cut -c2-)"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME_CAPITALIZED}/g" ${OUTPUT_DIR}/Chart.yaml

  # Rename templates directory
  printf "\n\n${red}[helm template]${no_color} Rename templates directory\n\n"
  mv ${OUTPUT_DIR}/templates/servicename ${OUTPUT_DIR}/templates/${SERVICE_NAME}

  # Update service name in template files
  printf "\n\n${red}[helm template]${no_color} Rename service in templates files\n\n"
  find ${OUTPUT_DIR}/templates/${SERVICE_NAME} -type f -exec ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml {} \;

  # Update service name in values file
  printf "\n\n${red}[helm template]${no_color} Rename service in 'values.yaml' file\n\n"
  yq eval ".${SERVICE_NAME} = .servicename | del(.servicename)" -i ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/servicename/${SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Update chart name in values
  printf "\n\n${red}[helm template]${no_color} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Delete tmp directory
  rm -rf ${OUTPUT_DIR}/tmp
fi


if [ -n "$ADDITIONAL_SERVICE_NAME" ]; then
  # Create tmp directory
  mkdir -p ${OUTPUT_DIR}/tmp

  # Clone additional service
  printf "\n\n${red}[helm template]${no_color} Clone additional service\n\n"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template/templates/servicename" \
    -o "${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}" \
    -d
  mv ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/servicename/* ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}
  rm -rf ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/template
  rm -rf ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME}/servicename

  # Update service name in template files
  printf "\n\n${red}[helm template]${no_color} Rename service in templates files\n\n"
  find ${OUTPUT_DIR}/templates/${ADDITIONAL_SERVICE_NAME} -type f -exec ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml {} \;

  # Update service name in values file
  printf "\n\n${red}[helm template]${no_color} Rename service in 'values.yaml' file\n\n"
  curl -fsSL https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/clone-subdir.sh | bash -s -- \
    -u "https://github.com/this-is-tobi/helm-charts" \
    -s "template/values.yaml" \
    -o "${OUTPUT_DIR}/tmp" \
    -d
  yq eval ".${ADDITIONAL_SERVICE_NAME} = load(\"${OUTPUT_DIR}/tmp/values.yaml\").servicename" -i ${OUTPUT_DIR}/values.yaml
  ${SED_COMMAND} -i "s/servicename/${ADDITIONAL_SERVICE_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Update chart name in values
  printf "\n\n${red}[helm template]${no_color} Rename chart in 'values.yaml' file\n\n"
  ${SED_COMMAND} -i "s/chartname/${CHART_NAME}/g" ${OUTPUT_DIR}/values.yaml

  # Delete tmp directory
  rm -rf ${OUTPUT_DIR}/tmp
fi

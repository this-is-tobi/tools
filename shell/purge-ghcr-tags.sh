#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
GITHUB_TOKEN=""
USER=""
IMAGE_NAME=""
if [ $(uname) = 'Darwin' ]; then 
  DATE="$(date -v -1m '+%Y-%m-%d')"
else
  DATE="$(date -d '1 month ago' '+%Y-%m-%d')"
fi

# Script helper
TEXT_HELPER="
This script aims to delete ghcr image tags with all its subsequent images older than a given date.

Available flags:
  -d    Date from which images will be deleted (format: 'yyyy-mm-dd')
        Default: '1 month ago'.
  -g    Github token to perform api calls.
  -i    Image name used for api calls.
  -u    Github user used for api calls.
  -h    Print script help.

Example:
  ./purge-ghcr-tags.sh \\
    -d '2024-01-01' \\
    -g 'ghp_xxx' \\
    -i 'my-image' \\
    -u 'this-is-tobi'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hd:g:i:u: flag; do
  case "${flag}" in
    d)
      DATE=${OPTARG};;
    g)
      GITHUB_TOKEN=${OPTARG};;
    i)
      IMAGE_NAME=${OPTARG};;
    u)
      USER=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > GITHUB_USER: ${USER}
  > IMAGE_NAME: ${IMAGE_NAME}
  > DATE: ${DATE}
"

# Options validation
if [ -z "$GITHUB_TOKEN" ] || [ -z "$USER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$DATE" ]; then
  echo "\nYMissing arguments ...\n"
  print_help
  exit 1
fi

# init
IMAGE_NAME_URL_ENCODED="$(jq -rn --arg x ${IMAGE_NAME} '$x | @uri')"
IMAGES=$(curl -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/users/${USER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions?per_page=100" \
  | jq -c --arg d "$DATE" '.[] | select(.created_at < $d)')

# Delete images
for IMAGE in $IMAGES; do
  IMAGE_ID="$(echo $IMAGE | jq '.id')"
  printf "\n${COLOR_RED}[Delete ghcr image].${COLOR_OFF} Deleting image '$USER/$IMAGE_NAME' with id '$IMAGE_ID'\n"

  curl -s \
    -X DELETE \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/users/${USER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions/${IMAGE_ID}"
done

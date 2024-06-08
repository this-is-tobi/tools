#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
if [ $(uname) = 'Darwin' ]; then 
  DATE="$(date -v -1m '+%Y-%m-%d')"
else
  DATE="$(date -d '1 month ago' '+%Y-%m-%d')"
fi

# Declare script helper
TEXT_HELPER="\nThis script aims to delete ghcr image tags with all its subsequent images older than a given date.
Following flags are available:

  -d    Date from which images will be deleted (format: 'yyyy-mm-dd', default is 1 month ago).

  -g    Github token to perform api calls.

  -i    Image name used for api calls.

  -u    Github user used for api calls.

  -h    Print script help.\n\n"

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


if [ -z "$GITHUB_TOKEN" ] || [ -z "$USER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$DATE" ]; then
  echo "\nYMissing arguments ...\n"
  print_help
  exit 1
fi

IMAGE_NAME_URL_ENCODED="$(jq -rn --arg x ${IMAGE_NAME} '$x | @uri')"
IMAGES=$(curl -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/users/${USER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions?per_page=100" \
  | jq -c --arg d "$DATE" '.[] | select(.created_at < $d)')

for IMAGE in $IMAGES; do
  IMAGE_ID="$(echo $IMAGE | jq '.id')"
  printf "\n${red}[Delete ghcr image].${no_color} Deleting image '$USER/$IMAGE_NAME' with id '$IMAGE_ID'\n"

  curl -s \
    -X DELETE \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/users/${USER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions/${IMAGE_ID}"
done

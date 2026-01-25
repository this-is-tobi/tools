#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
MODE="users"

# Versions
DOCKER_VERSION="$(docker --version)"
DOCKER_BUILDX_VERSION="$(docker buildx version)"

# Script helper
TEXT_HELPER="
This script aims to delete an image with all its subsequent images in ghcr.

Available flags:
  -g    Github token to perform api calls.
  -i    Image name used for api calls.
  -o    Github owner (organization or user) used for api calls.
  -t    Image tage to delete.
  -h    Print script help.

Example:
  ./delete-ghcr-image.sh \\
    -g 'ghp_xxxxyyyzzzz' \\
    -o 'this-is-tobi' \\
    -i 'tools' \\
    -t '1.0.0'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

checkDockerRunning () {
  if [ ! -x "$(command -v docker)" ]; then
    printf "\nThis script uses docker, and it isn't running - please start docker and try again!\n"
    exit 1
  fi
}

checkBuildxPlugin () {
  if [ ! "$DOCKER_BUILDX_VERSION" ]; then
    printf "\nThis script uses docker buildx plugin, and it isn't installed - please install docker buildx plugin and try again!\n"
    exit 1
  fi
}

# Parse options
while getopts hg:i:o:t: flag; do
  case "${flag}" in
    g)
      GITHUB_TOKEN=${OPTARG};;
    i)
      IMAGE_NAME=${OPTARG};;
    o)
      OWNER=${OPTARG};;
    t)
      TAG=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > DOCKER_VERSION: ${DOCKER_VERSION}
  > DOCKER_BUILDX_VERSION: ${DOCKER_BUILDX_VERSION}

  > OWNER: ${OWNER}
  > IMAGE_NAME: ${IMAGE_NAME}
  > TAG: ${TAG}
"

# Options validation
if [ -z "$GITHUB_TOKEN" ] || [ -z "$OWNER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$TAG" ]; then
  echo "\nYMissing arguments ...\n"
  print_help
  exit 1
fi
if [ $(checkDockerRunning) ]; then
  echo "\nDocker is not running ...\n"
  exit 1
fi
if [ $(checkBuildxPlugin) ]; then
  echo "\nDocker buildx plugin is not installed ...\n"
  exit 1
fi

# Init
if [ "$(curl -s "https://api.github.com/users/$OWNER" | jq -r '.type')" = "Organization" ]; then
  MODE="orgs"
elif [ "$(curl -s "https://api.github.com/users/$OWNER" | jq -r '.type')" = "User" ]; then
  MODE="users"
else
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Owner '$OWNER' not found on Github.\n"
  exit 1
fi

IMAGE_NAME_URL_ENCODED="$(jq -rn --arg x ${IMAGE_NAME} '$x | @uri')"
IMAGES=$(curl -s \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/${MODE}/${OWNER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions?per_page=100")
MAIN_IMAGE_ID=$(echo "$IMAGES" | jq -r --arg t "$TAG" '.[] | select(.metadata.container.tags[] | contains($t)) | .id')

# Delete subsequent images
while read -r SHA; do
  IMAGE_ID=$(echo "$IMAGES" | jq -r --arg s "$SHA" '.[] | select(.name == $s) | .id')

  printf "\n${COLOR_RED}[Delete ghcr image].${COLOR_OFF} Deleting subsequent image '$OWNER/$IMAGE_NAME@$SHA'\n"

  curl -s \
    -X DELETE \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    "https://api.github.com/${MODE}/${OWNER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions/${IMAGE_ID}"
done <<< "$(docker buildx imagetools inspect ghcr.io/${OWNER}/${IMAGE_NAME}:${TAG} --raw | jq -r '.manifests[] | .digest')"

# Delete main image
printf "\n${COLOR_RED}[Delete ghcr image].${COLOR_OFF} Deleting image '$OWNER/$IMAGE_NAME:$TAG'\n"

curl -s \
  -X DELETE \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  "https://api.github.com/${MODE}/${OWNER}/packages/container/${IMAGE_NAME_URL_ENCODED}/versions/${MAIN_IMAGE_ID}"

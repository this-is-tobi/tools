#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'

# Defaults
MODE="users"
TOKEN=""
IMAGE_NAME=""
OWNER=""
TAG=""
DRY_RUN="false"
FORCE="false"

# Script helper
TEXT_HELPER="
This script aims to delete an image with all its subsequent images in ghcr.

The package version carrying exactly the given tag is deleted, together with the
untagged manifests it references (platform images, attestations). Deleting a
version deletes all of its tags: when it carries other tags too (e.g. 'latest'),
the script stops unless -f is given.

Authentication:
  The token is read from GH_TOKEN, then GITHUB_TOKEN, then 'gh auth token'; it
  needs the read:packages and delete:packages scopes. Passing it with -g still
  works, but exposes it in the process list and the shell history.
  Referenced manifests are listed with 'docker buildx imagetools inspect', which
  uses your docker credentials for private images ('docker login ghcr.io').

Available flags:
  -f    Delete the version even when it carries other tags.
  -g    Github token to perform api calls (prefer GH_TOKEN / GITHUB_TOKEN).
  -i    Image name used for api calls.
  -n    Dry run: print what would be deleted without deleting anything.
  -o    Github owner (organization or user) used for api calls.
  -t    Image tag to delete.
  -h    Print script help.

Example:
  ./delete-ghcr-image.sh \\
    -o 'this-is-tobi' \\
    -i 'tools' \\
    -t '1.0.0' \\
    -n
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# A token given with -g is visible in the process list and the shell history:
# the environment and the gh CLI keep it out of both.
resolve_token() {
  if [ -z "$TOKEN" ]; then
    TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  fi
  if [ -z "$TOKEN" ] && command -v gh > /dev/null 2>&1; then
    TOKEN="$(gh auth token 2> /dev/null || true)"
  fi
}

# Calls the GitHub API; curl reads the Authorization header through a file
# descriptor so the token never appears in its arguments.
github_api() {
  local method="$1"
  local url="$2"

  curl -fsSL -X "$method" "$url" \
    -H @<(printf 'Authorization: Bearer %s\n' "$TOKEN") \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28"
}

# Prints every version of the package as one JSON array, following pagination.
list_versions() {
  local page=1
  local count

  while true; do
    github_api GET "$PACKAGE_URL/versions?per_page=100&page=$page" > "$WORK_DIR/page-$page.json"
    count=$(jq 'length' "$WORK_DIR/page-$page.json")
    [ "$count" -lt 100 ] && break
    page=$((page + 1))
  done

  jq -s 'add // []' "$WORK_DIR"/page-*.json
}

# Prints the digests referenced by a manifest list / image index (nothing for a single image).
child_digests() {
  docker buildx imagetools inspect --raw "$1" | jq -r '.manifests[]?.digest'
}

delete_version() {
  local id="$1"
  local label="$2"

  if [ "$DRY_RUN" = "true" ]; then
    printf "${COLOR_YELLOW}[dry run]${COLOR_OFF} Would delete %s (version id %s)\n" "$label" "$id"
  else
    printf "${COLOR_RED}[Delete ghcr image].${COLOR_OFF} Deleting %s (version id %s)\n" "$label" "$id"
    github_api DELETE "$PACKAGE_URL/versions/$id" > /dev/null
  fi
}

# Parse options
while getopts hfg:i:no:t: flag; do
  case "${flag}" in
    f)
      FORCE="true";;
    g)
      TOKEN=${OPTARG}
      printf "${COLOR_YELLOW}Warning.${COLOR_OFF} Token passed with -g: it is visible in the process list and the shell history, prefer GH_TOKEN.\n" >&2;;
    i)
      IMAGE_NAME=${OPTARG};;
    n)
      DRY_RUN="true";;
    o)
      OWNER=${OPTARG};;
    t)
      TAG=${OPTARG};;
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
  > OWNER: ${OWNER}
  > IMAGE_NAME: ${IMAGE_NAME}
  > TAG: ${TAG}
  > DRY_RUN: ${DRY_RUN}
  > FORCE: ${FORCE}
"

# Options validation
resolve_token
if [ -z "$TOKEN" ] || [ -z "$OWNER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$TAG" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Missing arguments: owner (-o), image (-i), tag (-t) and a token (GH_TOKEN, GITHUB_TOKEN, 'gh auth login' or -g) are required.\n" >&2
  print_help >&2
  exit 1
fi
if ! command -v docker > /dev/null 2>&1; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} This script uses docker, and it isn't installed - please install docker and try again!\n" >&2
  exit 1
fi
if ! docker buildx version > /dev/null 2>&1; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} This script uses docker buildx plugin, and it isn't installed - please install docker buildx plugin and try again!\n" >&2
  exit 1
fi

# Init
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/delete-ghcr-image.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

OWNER_TYPE="$(github_api GET "https://api.github.com/users/$OWNER" | jq -r '.type // empty')" || true
if [ "$OWNER_TYPE" = "Organization" ]; then
  MODE="orgs"
elif [ "$OWNER_TYPE" = "User" ]; then
  MODE="users"
else
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Owner '%s' not found on Github.\n" "$OWNER" >&2
  exit 1
fi

IMAGE_NAME_URL_ENCODED="$(jq -rn --arg x "$IMAGE_NAME" '$x | @uri')"
PACKAGE_URL="https://api.github.com/${MODE}/${OWNER}/packages/container/${IMAGE_NAME_URL_ENCODED}"
IMAGE_REF="ghcr.io/$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')/${IMAGE_NAME}"

list_versions > "$WORK_DIR/versions.json"

# Exact tag match: '1.0' must not select the version tagged '1.0.0'.
MAIN_VERSION="$(jq -c --arg t "$TAG" '[.[] | select(any(.metadata.container.tags[]?; . == $t))][0] // empty' "$WORK_DIR/versions.json")"
if [ -z "$MAIN_VERSION" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Tag '%s' not found for image '%s/%s'.\n" "$TAG" "$OWNER" "$IMAGE_NAME" >&2
  exit 1
fi
MAIN_IMAGE_ID="$(jq -r '.id' <<< "$MAIN_VERSION")"
MAIN_DIGEST="$(jq -r '.name' <<< "$MAIN_VERSION")"
OTHER_TAGS="$(jq -r --arg t "$TAG" '[.metadata.container.tags[] | select(. != $t)] | join(", ")' <<< "$MAIN_VERSION")"

if [ -n "$OTHER_TAGS" ]; then
  if [ "$FORCE" = "true" ]; then
    printf "\n${COLOR_YELLOW}Warning.${COLOR_OFF} These tags are deleted too: %s\n" "$OTHER_TAGS" >&2
  else
    printf "\n${COLOR_RED}Error.${COLOR_OFF} The version tagged '%s' also carries: %s. Deleting it deletes all of them, use -f to confirm.\n" "$TAG" "$OTHER_TAGS" >&2
    exit 1
  fi
fi

# Delete subsequent images
# Only untagged children are deleted: a tagged one is an image in its own right.
CHILD_DIGESTS="$(child_digests "$IMAGE_REF@$MAIN_DIGEST")"
while IFS= read -r SHA; do
  [ -z "$SHA" ] && continue
  CHILD="$(jq -c --arg s "$SHA" '[.[] | select(.name == $s)][0] // empty' "$WORK_DIR/versions.json")"
  if [ -z "$CHILD" ]; then
    printf "${COLOR_YELLOW}Skipping${COLOR_OFF} '%s': not a version of this package.\n" "$SHA"
    continue
  fi
  if [ "$(jq '.metadata.container.tags | length' <<< "$CHILD")" -gt 0 ]; then
    printf "${COLOR_YELLOW}Skipping${COLOR_OFF} '%s': it carries its own tags.\n" "$SHA"
    continue
  fi
  delete_version "$(jq -r '.id' <<< "$CHILD")" "subsequent image '$OWNER/$IMAGE_NAME@$SHA'"
done <<< "$CHILD_DIGESTS"

# Delete main image
delete_version "$MAIN_IMAGE_ID" "image '$OWNER/$IMAGE_NAME:$TAG'"

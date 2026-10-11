#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
TOKEN=""
OWNER=""
IMAGE_NAME=""
DRY_RUN="false"
PROTECT_RELEASES="true"
# 'latest', versions such as '1', '1.2', 'v1.2.3', '1.2.3-rc.1' and component releases such as 'api-v1.2.3'.
# The major number is capped at 4 digits so date tags ('20241012', '20241012-1a2b3c4') stay purgeable.
PROTECTED_TAGS_REGEX='^(latest|v?[0-9]{1,4}(\.[0-9]+){0,2}|v?[0-9]{1,4}\.[0-9]+\.[0-9]+[-+][0-9A-Za-z.-]+|.+-v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?)$'
if [ "$(uname)" = 'Darwin' ]; then
  DATE="$(date -v -1m '+%Y-%m-%d')"
else
  DATE="$(date -d '1 month ago' '+%Y-%m-%d')"
fi

# Script helper
TEXT_HELPER="
This script aims to delete ghcr image tags with all its subsequent images older than a given date.

What is kept:
  - versions created on or after the date;
  - release versions: any version carrying a tag that matches the protected tags
    regex (by default 'latest', '1', '1.2', 'v1.2.3', '1.2.3-rc.1', 'api-v1.2.3'),
    whatever their age, unless -a is given;
  - every manifest referenced by a kept version (platform images, attestations),
    and signatures / attestations stored under 'sha256-<digest>' tags of a kept
    version.
Everything else older than the date is deleted. Run with -n first.

Authentication:
  The token is read from GH_TOKEN, then GITHUB_TOKEN, then 'gh auth token'; it
  needs the read:packages and delete:packages scopes. Passing it with -g still
  works, but exposes it in the process list and the shell history.
  Referenced manifests are listed with 'docker buildx imagetools inspect', which
  uses your docker credentials for private images ('docker login ghcr.io').

Available flags:
  -a    Also delete release versions older than the date.
  -d    Date from which images will be deleted (format: 'yyyy-mm-dd')
        Default: '1 month ago'.
  -g    Github token to perform api calls (prefer GH_TOKEN / GITHUB_TOKEN).
  -i    Image name used for api calls.
  -n    Dry run: print what would be deleted without deleting anything.
  -p    Protected tags regex.
        Default: '$PROTECTED_TAGS_REGEX'.
  -u    Github owner (user or organization) used for api calls.
  -h    Print script help.

Example:
  ./purge-ghcr-tags.sh \\
    -d '2024-01-01' \\
    -i 'my-image' \\
    -u 'this-is-tobi' \\
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

# Shared jq helpers: tags of a version, and whether it only holds 'sha256-<digest>'
# tags (cosign signatures, attestations, referrers fallback tags).
JQ_DEFS='
  def tags: (.metadata.container.tags // []);
  def referrer: (tags | length) > 0 and all(tags[]; test("^sha256-[0-9a-f]{64}"));
  def subjects: [tags[] | "sha256:" + .[7:71]];
  def protected: $protect and any(tags[]; test($re));
'

# Parse options
while getopts had:g:i:np:u: flag; do
  case "${flag}" in
    a)
      PROTECT_RELEASES="false";;
    d)
      DATE=${OPTARG};;
    g)
      TOKEN=${OPTARG}
      printf "${COLOR_YELLOW}Warning.${COLOR_OFF} Token passed with -g: it is visible in the process list and the shell history, prefer GH_TOKEN.\n" >&2;;
    i)
      IMAGE_NAME=${OPTARG};;
    n)
      DRY_RUN="true";;
    p)
      PROTECTED_TAGS_REGEX=${OPTARG};;
    u)
      OWNER=${OPTARG};;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Anything left after the flags is a mistake (getopts stops at the first non-option)
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  printf "Unexpected argument: '%s'.\n" "$1" >&2
  print_help >&2
  exit 1
fi

# Settings
printf "
Settings:
  > GITHUB_OWNER: ${OWNER}
  > IMAGE_NAME: ${IMAGE_NAME}
  > DATE: ${DATE}
  > PROTECT_RELEASES: ${PROTECT_RELEASES}
  > PROTECTED_TAGS_REGEX: ${PROTECTED_TAGS_REGEX}
  > DRY_RUN: ${DRY_RUN}
"

# Options validation
resolve_token
if [ -z "$TOKEN" ] || [ -z "$OWNER" ] || [ -z "$IMAGE_NAME" ] || [ -z "$DATE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Missing arguments: owner (-u), image (-i) and a token (GH_TOKEN, GITHUB_TOKEN, 'gh auth login' or -g) are required.\n" >&2
  print_help >&2
  exit 1
fi
if ! printf '%s' "$DATE" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid date '%s' (expected 'yyyy-mm-dd').\n" "$DATE" >&2
  exit 1
fi
if ! jq -n --arg re "$PROTECTED_TAGS_REGEX" '"latest" | test($re)' > /dev/null 2>&1; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid protected tags regex: '%s'.\n" "$PROTECTED_TAGS_REGEX" >&2
  exit 1
fi
if ! command -v docker > /dev/null 2>&1 || ! docker buildx version > /dev/null 2>&1; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} This script uses docker buildx to find the manifests referenced by kept images - please install docker and the buildx plugin and try again!\n" >&2
  exit 1
fi

# Init
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/purge-ghcr-tags.XXXXXX")"
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
VERSIONS="$WORK_DIR/versions.json"
KEPT="$WORK_DIR/kept.txt"

printf "\n${COLOR_BLUE}[Purge ghcr image].${COLOR_OFF} List package versions\n"
list_versions > "$VERSIONS"
printf "%s version(s) found.\n" "$(jq 'length' "$VERSIONS")"

# Kept images: tagged versions that are recent or protected.
jq -r --arg d "$DATE" --arg re "$PROTECTED_TAGS_REGEX" --argjson protect "$PROTECT_RELEASES" "$JQ_DEFS"'
  .[] | select((tags | length) > 0 and (referrer | not))
      | select(.created_at >= $d or protected)
      | .name' "$VERSIONS" > "$KEPT"

# Keep what kept images reference, then the signatures / attestations of anything kept,
# and what those reference in turn, until nothing new shows up.
EXPAND="$(cat "$KEPT")"
while [ -n "$EXPAND" ]; do
  printf "\n${COLOR_BLUE}[Purge ghcr image].${COLOR_OFF} Inspect %s kept image(s) for referenced manifests\n" "$(printf '%s\n' "$EXPAND" | wc -l | tr -d ' ')"
  while IFS= read -r DIGEST; do
    if ! CHILDREN="$(child_digests "$IMAGE_REF@$DIGEST")"; then
      printf "\n${COLOR_RED}Error.${COLOR_OFF} Could not inspect '%s@%s': stopping so that no referenced manifest gets deleted.\n" "$IMAGE_REF" "$DIGEST" >&2
      exit 1
    fi
    if [ -n "$CHILDREN" ]; then
      printf '%s\n' "$CHILDREN" >> "$KEPT"
    fi
  done <<< "$EXPAND"

  jq -R -s 'split("\n") | map(select(. != ""))' "$KEPT" > "$WORK_DIR/kept.json"
  EXPAND="$(jq -r --arg d "$DATE" --arg re "$PROTECTED_TAGS_REGEX" --argjson protect "$PROTECT_RELEASES" --slurpfile k "$WORK_DIR/kept.json" "$JQ_DEFS"'
    $k[0] as $kept
    | .[] | select(referrer)
    | .name as $n | select(($kept | index([$n])) == null)
    | select(.created_at >= $d or (subjects | any(. as $s | $kept | index([$s]) != null)))
    | .name' "$VERSIONS")"
  if [ -n "$EXPAND" ]; then
    printf '%s\n' "$EXPAND" >> "$KEPT"
  fi
done

jq -R -s 'split("\n") | map(select(. != ""))' "$KEPT" > "$WORK_DIR/kept.json"

# Delete images
TO_DELETE="$(jq -r --arg d "$DATE" --arg re "$PROTECTED_TAGS_REGEX" --argjson protect "$PROTECT_RELEASES" --slurpfile k "$WORK_DIR/kept.json" "$JQ_DEFS"'
  $k[0] as $kept
  | .[] | select(.created_at < $d)
  | .name as $n | select(($kept | index([$n])) == null)
  | select(protected | not)
  | [(.id | tostring), .name, (if (tags | length) > 0 then (tags | join(",")) else "untagged" end)] | @tsv' "$VERSIONS")"

if [ -z "$TO_DELETE" ]; then
  printf "\n${COLOR_GREEN}Nothing to delete.${COLOR_OFF}\n"
  exit 0
fi

DELETED=0
while IFS="$(printf '\t')" read -r IMAGE_ID IMAGE_DIGEST IMAGE_TAGS; do
  if [ "$DRY_RUN" = "true" ]; then
    printf "${COLOR_YELLOW}[dry run]${COLOR_OFF} Would delete image '%s@%s' (%s, version id %s)\n" "$IMAGE_NAME" "$IMAGE_DIGEST" "$IMAGE_TAGS" "$IMAGE_ID"
  else
    printf "${COLOR_RED}[Delete ghcr image].${COLOR_OFF} Deleting image '%s@%s' (%s, version id %s)\n" "$IMAGE_NAME" "$IMAGE_DIGEST" "$IMAGE_TAGS" "$IMAGE_ID"
    github_api DELETE "$PACKAGE_URL/versions/$IMAGE_ID" > /dev/null
  fi
  DELETED=$((DELETED + 1))
done <<< "$TO_DELETE"

if [ "$DRY_RUN" = "true" ]; then
  printf "\n${COLOR_GREEN}Dry run: %s version(s) would be deleted.${COLOR_OFF}\n" "$DELETED"
else
  printf "\n${COLOR_GREEN}%s version(s) deleted.${COLOR_OFF}\n" "$DELETED"
fi

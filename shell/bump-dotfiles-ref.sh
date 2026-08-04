#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
REPO_URL="https://github.com/this-is-tobi/dotfiles"
GIT_BRANCH="main"
TARGET_REF=""
DRY_RUN="false"
DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/docker/utils"

# Script helper
TEXT_HELPER="
This script updates the pinned dotfiles commit (ARG DOTFILES_REF) in every
Dockerfile that clones the dotfiles repository, in one pass.

Renovate keeps this pin current on its own (see the customManager in
renovate.json, which groups all images into a single PR). Use this script when
you want the bump immediately rather than waiting for that PR.

Available flags:
  -b  Branch to resolve the latest commit from.
      Default: '$GIT_BRANCH'.
  -n  Dry run, print what would change without writing.
      Default: '$DRY_RUN'.
  -r  Explicit commit sha to pin. Overrides -b.
  -u  Url of the dotfiles repository.
      Default: '$REPO_URL'.
  -h  Print script help.

Example:
  ./bump-dotfiles-ref.sh
  ./bump-dotfiles-ref.sh -r 972015d509ce8af4a886b43f91db4d14af60c356
  ./bump-dotfiles-ref.sh -b develop -n
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hb:nr:u: flag; do
  case "${flag}" in
    b)
      GIT_BRANCH="${OPTARG}";;
    n)
      DRY_RUN="true";;
    r)
      TARGET_REF="${OPTARG}";;
    u)
      REPO_URL="${OPTARG}";;
    h | *)
      print_help
      exit 0;;
  esac
done

# Resolve the target commit
if [ -z "$TARGET_REF" ]; then
  printf "\n\n${COLOR_RED}[bump dotfiles ref]${COLOR_OFF} Resolve latest commit on '${GIT_BRANCH}'\n\n"
  TARGET_REF="$(git ls-remote "$REPO_URL" "refs/heads/${GIT_BRANCH}" | cut -f1)"
fi

if ! printf '%s' "$TARGET_REF" | grep -Eq '^[0-9a-f]{40}$'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Could not resolve a full 40-character commit sha (got: '${TARGET_REF}').\n"
  exit 1
fi

# Settings
printf "
Settings:
  > REPO_URL: ${REPO_URL}
  > TARGET_REF: ${TARGET_REF}
  > DOCKER_DIR: ${DOCKER_DIR}
  > DRY_RUN: ${DRY_RUN}
"

# Update every Dockerfile carrying the pin
printf "\n\n${COLOR_RED}[bump dotfiles ref]${COLOR_OFF} Update Dockerfiles\n\n"

CHANGED=0
UNCHANGED=0

while IFS= read -r DOCKERFILE; do
  CURRENT="$(sed -n 's/^ARG DOTFILES_REF=\([0-9a-f]\{40\}\)$/\1/p' "$DOCKERFILE" | head -1)"
  [ -z "$CURRENT" ] && continue

  RELATIVE="${DOCKERFILE#"${DOCKER_DIR}/"}"

  if [ "$CURRENT" = "$TARGET_REF" ]; then
    printf "  ${COLOR_YELLOW}unchanged${COLOR_OFF}  %s\n" "$RELATIVE"
    UNCHANGED=$((UNCHANGED + 1))
    continue
  fi

  printf "  ${COLOR_GREEN}update${COLOR_OFF}     %s (%s -> %s)\n" "$RELATIVE" "${CURRENT:0:12}" "${TARGET_REF:0:12}"
  CHANGED=$((CHANGED + 1))

  if [ "$DRY_RUN" = "false" ]; then
    # -i '' is required on BSD sed (macOS) and rejected by GNU sed, so the file
    # is rewritten through a temporary instead of relying on either dialect.
    sed "s/^ARG DOTFILES_REF=.*$/ARG DOTFILES_REF=${TARGET_REF}/" "$DOCKERFILE" > "${DOCKERFILE}.tmp"
    mv "${DOCKERFILE}.tmp" "$DOCKERFILE"
  fi
done < <(grep -rl '^ARG DOTFILES_REF=' "$DOCKER_DIR" --include=Dockerfile | sort)

if [ "$CHANGED" -eq 0 ] && [ "$UNCHANGED" -eq 0 ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} No Dockerfile with an 'ARG DOTFILES_REF=' line found under ${DOCKER_DIR}.\n"
  exit 1
fi

printf "\n${COLOR_GREEN}Done.${COLOR_OFF} %s updated, %s already current.\n" "$CHANGED" "$UNCHANGED"

if [ "$DRY_RUN" = "true" ] && [ "$CHANGED" -gt 0 ]; then
  printf "${COLOR_YELLOW}Dry run - nothing was written.${COLOR_OFF}\n"
fi

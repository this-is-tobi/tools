#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Defaults
DELETE_GIT_DIR="false"
GIT_BRANCH="main"
OUTPUT_DIR="."
SUB_DIR=""
REPO_URL=""

# Script helper
TEXT_HELPER="
This script aims to clone a git subdirectory (or a single file).

The repository is cloned into a temporary directory, then the requested path is
copied into the output directory under its own name: '-s a/b/c -o out' creates
'out/c'. Nothing is written outside the output directory and no git metadata is
left behind.

Available flags:
  -b  Git branch to clone.
      Default: '$GIT_BRANCH'.
  -d  Kept for compatibility: the output never contains a '.git' directory.
  -o  Output directory where the subdirectory is copied.
      Default: current directory.
  -s  Sub-directory (or file) to clone, relative to the repository root.
  -u  Url of the target repository.
  -h  Print script help.

Example:
  ./clone-subdir.sh \\
    -u 'https://github.com/this-is-tobi/tools' \\
    -s 'shell' \\
    -o './tools' \\
    -b 'main'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hb:do:s:u: flag; do
  case "${flag}" in
    b)
      GIT_BRANCH="${OPTARG}";;
    d)
      DELETE_GIT_DIR="true";;
    o)
      OUTPUT_DIR="${OPTARG}";;
    s)
      SUB_DIR="${OPTARG}";;
    u)
      REPO_URL="${OPTARG}";;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Normalize the sub-directory: './a/b/' -> 'a/b'
SUB_DIR="${SUB_DIR#./}"
while [ "${SUB_DIR%/}" != "$SUB_DIR" ]; do
  SUB_DIR="${SUB_DIR%/}"
done

# Settings
printf "
Settings:
  > REPO_URL: ${REPO_URL}
  > SUB_DIR: ${SUB_DIR}
  > GIT_BRANCH: ${GIT_BRANCH}
  > OUTPUT_DIR: ${OUTPUT_DIR}
  > DELETE_GIT_DIR: ${DELETE_GIT_DIR}
"

# Options validation
if [ -z "$REPO_URL" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: repo url name (flag -u).\n" >&2
  exit 1
fi
if [ -z "$SUB_DIR" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: subdirectory to clone (flag -s).\n" >&2
  exit 1
fi
# The path is looked up inside the temporary clone: refuse anything that could
# resolve outside of it or to the whole repository.
case "/$SUB_DIR/" in
  //|/./|*/../*)
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid subdirectory '%s': use a path inside the repository.\n" "$SUB_DIR" >&2
    exit 1;;
esac
case "$SUB_DIR" in
  /*)
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid subdirectory '%s': use a path relative to the repository root.\n" "$SUB_DIR" >&2
    exit 1;;
esac

# Clone into a temporary directory so the current directory is never turned into a repository
CLONE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/clone-subdir.XXXXXX")"
trap 'rm -rf "$CLONE_DIR"' EXIT

printf "\n\n${COLOR_RED}[clone subdir]${COLOR_OFF} Clone repository\n\n"

git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$GIT_BRANCH" -- "$REPO_URL" "$CLONE_DIR/repo"
# Non-cone patterns accept a single file as well as a directory.
git -C "$CLONE_DIR/repo" sparse-checkout set --no-cone "/$SUB_DIR"

SOURCE="$CLONE_DIR/repo/$SUB_DIR"
if [ ! -e "$SOURCE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} '%s' does not exist on branch '%s' of '%s'.\n" "$SUB_DIR" "$GIT_BRANCH" "$REPO_URL" >&2
  exit 1
fi

# Copy the subdirectory into the output directory
printf "\n\n${COLOR_RED}[clone subdir]${COLOR_OFF} Copy '%s' into '%s'\n\n" "$SUB_DIR" "$OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"
TARGET="${OUTPUT_DIR%/}/$(basename "$SUB_DIR")"
if [ -d "$SOURCE" ]; then
  mkdir -p "$TARGET"
  cp -R "$SOURCE/." "$TARGET/"
else
  cp "$SOURCE" "$TARGET"
fi

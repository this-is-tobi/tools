#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
DELETE_GIT_DIR="false"
GIT_BRANCH="main"
OUTPUT_DIR="$(pwd)"

# Script helper
TEXT_HELPER="
This script aims to clone a git subdirectory.

Available flags:
  -b  Git branch to clone.
      Default: '$GIT_BRANCH'.
  -d  Delete git directory after clone.
      Default: '$DELETE_GIT_DIR'.
  -o  Output directory to clone the repository.
      Default: '$OUTPUT_DIR'.
  -s  Sub-directory to clone.
  -u  Url of the target repository.
  -h  Print script help.

Example:
  ./clone-subdir.sh \\
    -u 'https://github.com/this-is-tobi/tools' \\
    -s 'shell' \\
    -o './tools-shell' \\
    -b 'main' \\
    -d
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
    h | *)
      print_help
      exit 0;;
  esac
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
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: repo url name (flag -u)".
  exit 1
fi
if [ -z "$SUB_DIR" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: subdirectory to clone (flag -s)".
  exit 1
fi

# init git repository in the output dir
printf "\n\n${COLOR_RED}[clone subdir]${COLOR_OFF} Init git repository\n\n"

[ ! -d "$OUPUT_DIR" ] && mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"
git init 
git remote add origin "$REPO_URL"
git config core.sparsecheckout true

# Clone sub directory from the target repository
printf "\n\n${COLOR_RED}[clone subdir]${COLOR_OFF} Clone repository\n\n"

if [ -d "$SUB_DIR" ]; then
  echo "$SUB_DIR/*" >> .git/info/sparse-checkout
  git pull origin "$GIT_BRANCH"
  cp -aR "$SUB_DIR/." . && rm -rf "$SUB_DIR"
else
  echo "$SUB_DIR" >> .git/info/sparse-checkout
  git pull origin "$GIT_BRANCH"
  cp -a "$SUB_DIR" . && rm -rf $(dirname "$SUB_DIR")
fi
cd - > /dev/null

# Delete git artifacts in the fresh cloned repo
if [ "$DELETE_GIT_DIR" == "true" ]; then
  printf "\n\n${COLOR_RED}[clone subdir]${COLOR_OFF} Ungit cloned repoitory\n\n"

  rm -rf "${OUTPUT_DIR%/}/.git"
fi

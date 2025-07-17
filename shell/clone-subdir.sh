#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'


# Defaults
DELETE_GIT_DIR="false"
GIT_BRANCH="main"
OUTPUT_DIR="$(pwd)"

# Declare script helper
TEXT_HELPER="\nThis script aims to clone a git subdirectory.

Following flags are available:

  -b  Git branch to clone.
      Default is '$GIT_BRANCH'.

  -d  Delete git directory after clone.
      Default is '$DELETE_GIT_DIR'.

  -o  Output directory to clone the repository.
      Default is '$OUTPUT_DIR'.

  -s  Sub-directory to clone.

  -u  Url of the target repository.

  -h  Print script help.\n\n"

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


# Script conditions
if [ -z "$REPO_URL" ]; then
  printf "\n${red}Error.${no_color} Argument missing: repo url name (flag -u)".
  exit 1
fi
if [ -z "$SUB_DIR" ]; then
  printf "\n${red}Error.${no_color} Argument missing: subdirectory to clone (flag -s)".
  exit 1
fi


# init git repository in the output dir
printf "\n\n${red}[clone subdir]${no_color} Init git repository\n\n"

[ ! -d "$OUPUT_DIR" ] && mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"
git init 
git remote add origin "$REPO_URL"
git config core.sparsecheckout true


# Clone sub directory from the target repository
printf "\n\n${red}[clone subdir]${no_color} Clone repository\n\n"

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
  printf "\n\n${red}[clone subdir]${no_color} Ungit cloned repoitory\n\n"

  rm -rf "${OUTPUT_DIR%/}/.git"
fi

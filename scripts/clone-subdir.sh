#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Console step increment
i=1

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
while getopts b:do:s:u: flag; do
  case "${flag}" in
    b)
      GIT_BRANCH="${OPTARG}";;
    d)
      DELETE_GIT_DIR="true";;
    o)
      OUTPUT_DIR="true";;
    s)
      SUB_DIR="${OPTARG}";;
    u)
      REPO_URL="${OPTARG}";;
    h | *)
      print_help
      exit 0;;
  esac
done


REPO_NAME="$(echo $REPO_URL | grep -oE '[^/]+$')"


# init git repository in the output dir
printf "\n\n${red}${i}.${no_color} Init git repository\n\n"
i=$(($i + 1))

mkdir -p "$OUTPUT_DIR/$REPO_NAME"
cd "$OUTPUT_DIR/$REPO_NAME"
git init 
git remote add origin "$REPO_URL"
git config core.sparsecheckout true


# Clone sub directory from the target repository
printf "\n\n${red}${i}.${no_color} Clone repository\n\n"
i=$(($i + 1))

echo "$SUB_DIR/*" >> .git/info/sparse-checkout
git pull origin "$GIT_BRANCH"


# Delete git artifacts in the fresh cloned repo
if [ "$DELETE_GIT_DIR" = "true" ]; then
  printf "\n\n${red}${i}.${no_color} ungit previously cloned repoitory\n\n"
  i=$(($i + 1))

  mv "$OUTPUT_DIR/$REPO_NAME/$SUB_DIR/" "$OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR/$REPO_NAME"
fi

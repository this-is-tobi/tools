#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Script helper
TEXT_HELPER="
This script aims to copy '.env*-example' files into '.env*' and '*-example.yaml' files into '*.yaml' at project initialization.

Available flags:
  -h    Print script help.
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts h flag
do
  case "${flag}" in
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Defaults
# The repository root, or the current directory outside of a git repository
PROJECT_DIR="$(git rev-parse --show-toplevel 2> /dev/null || pwd)"

find "$PROJECT_DIR" -type f \( -name ".env*-example" -o -name "*-example.yaml" \) | while IFS= read -r f; do
  if [ ! -f "${f/-example/}" ]; then
    printf "\n${COLOR_RED}Copy${COLOR_OFF}: '$f'"
    printf "\n${COLOR_RED}  to${COLOR_OFF}: '${f/-example/}'\n"
    cp "$f" "${f/-example/}"
  else
    printf "\n${COLOR_RED}File${COLOR_OFF}: '${f/-example/}' ${COLOR_RED}already exists${COLOR_OFF}\n"
  fi
done

find "$PROJECT_DIR" -type f \( -name ".env*.example" -o -name "*.example.yaml" \) | while IFS= read -r f; do
  if [ ! -f "${f/.example/}" ]; then
    printf "\n${COLOR_RED}Copy${COLOR_OFF}: '$f'"
    printf "\n${COLOR_RED}  to${COLOR_OFF}: '${f/.example/}'\n"
    cp "$f" "${f/.example/}"
  else
    printf "\n${COLOR_RED}File${COLOR_OFF}: '${f/.example/}' ${COLOR_RED}already exists${COLOR_OFF}\n"
  fi
done

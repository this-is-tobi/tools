#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
PROJECT_DIR="$(git rev-parse --show-toplevel)"

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
    h | *)
      print_help
      exit 0;;
  esac
done

find ${PROJECT_DIR:-.} -type f -name ".env*-example" -or -name "*-example.yaml" | while read f; do
  if [ ! -f "${f/-example/}" ]; then
    printf "\n${COLOR_RED}Copy${COLOR_OFF}: '$f'"
    printf "\n${COLOR_RED}  to${COLOR_OFF}: '${f/-example/}'\n"
    cp "$f" "${f/-example/}"
  else
    printf "\n${COLOR_RED}File${COLOR_OFF}: '${f/-example/}' ${COLOR_RED}already exists${COLOR_OFF}\n"
  fi
done

find ${PROJECT_DIR:-.} -type f -name ".env*.example" -or -name "*.example.yaml" | while read f; do
  if [ ! -f "${f/.example/}" ]; then
    printf "\n${COLOR_RED}Copy${COLOR_OFF}: '$f'"
    printf "\n${COLOR_RED}  to${COLOR_OFF}: '${f/.example/}'\n"
    cp "$f" "${f/.example/}"
  else
    printf "\n${COLOR_RED}File${COLOR_OFF}: '${f/.example/}' ${COLOR_RED}already exists${COLOR_OFF}\n"
  fi
done

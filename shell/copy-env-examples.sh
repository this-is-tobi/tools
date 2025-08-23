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
This script aims to copy .env-example files into .env files at project initialization.

Available flags:
  -h    Print script help.
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts h flag; do
  case "${flag}" in
    h | *)
      print_help
      exit 0;;
  esac
done

find $PROJECT_DIR -type f -name ".env*-example" | while read f; do
  printf "\n${COLOR_RED}Copy${COLOR_OFF}: '$f' 
  ${COLOR_RED}to${COLOR_OFF}: '${f/-example/}'\n\n"
  cp "$f" ${f/-example/}
done

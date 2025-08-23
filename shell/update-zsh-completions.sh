#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
ZSH_COMPLETIONS_DIR="${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions"

# Script helper
TEXT_HELPER="
This script aims to update zsh-completions sources (See. https://github.com/zsh-users/zsh-completions).

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

# Update zsh-completions
if [ ! -d "$ZSH_COMPLETIONS_DIR" ]; then
  printf "\nzsh-completion directory does not exists, cloning repository.\n\n"
  git clone https://github.com/zsh-users/zsh-completions $ZSH_COMPLETIONS_DIR
else
  git -C $ZSH_COMPLETIONS_DIR pull
fi

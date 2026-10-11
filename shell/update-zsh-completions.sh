#!/bin/bash

set -euo pipefail

# Defaults
ZSH_COMPLETIONS_DIR="${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-completions"

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
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Update zsh-completions
if [ ! -d "$ZSH_COMPLETIONS_DIR" ]; then
  printf "\nzsh-completion directory does not exists, cloning repository.\n\n"
  git clone https://github.com/zsh-users/zsh-completions "$ZSH_COMPLETIONS_DIR"
else
  git -C "$ZSH_COMPLETIONS_DIR" pull
fi

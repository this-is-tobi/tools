#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Defaults
ZSH_COMPLETIONS_DIR="${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions"


# Declare script helper
TEXT_HELPER="\nThis script aims to update zsh-completions sources (See. https://github.com/zsh-users/zsh-completions).
Following flags are available:

  -h    Print script help\n\n"

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

if [ ! -d "$ZSH_COMPLETIONS_DIR" ]; then
  printf "\nzsh-completion directory does not exists, cloning repository.\n\n"
  git clone https://github.com/zsh-users/zsh-completions $ZSH_COMPLETIONS_DIR
else
  git -C $ZSH_COMPLETIONS_DIR pull
fi

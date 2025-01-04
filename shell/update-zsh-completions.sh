#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'


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

git -C ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions pull

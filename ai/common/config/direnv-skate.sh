#!/usr/bin/env bash

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'

# Script helper
TEXT_HELPER="
This file is a direnv layout, not a standalone script — it defines a 'use_skate' function for
direnv to call, nothing runs by executing it directly (a child process can't export vars into
your parent shell anyway, so there is no useful 'run' behavior here).

Setup, once, in '~/.config/direnv/direnvrc':
  source /path/to/direnv-skate.sh

Usage, per project, in that project's '.envrc':
  use skate ARGOCD_API_TOKEN=argocd_api_token CONTEXT7_API_KEY=context7_api_key

Each 'VAR=key' pair exports VAR in the current direnv-managed shell, with its value fetched
fresh from 'skate get key'. Nothing is written to disk, and the export is scoped to this
directory — direnv unloads it automatically once you 'cd' out.

Available flags:
  -h    Print script help.
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

use_skate() {
  local pair var key
  for pair in "$@"; do
    var="${pair%%=*}"
    key="${pair#*=}"
    if [ -z "$var" ] || [ -z "$key" ] || [ "$var" = "$pair" ]; then
      echo "use_skate: skipping invalid pair '${pair}' (expected VAR=skate_key)" >&2
      continue
    fi
    if ! command -v skate > /dev/null 2>&1; then
      echo "use_skate: 'skate' not found in PATH, skipping ${var}" >&2
      continue
    fi
    export "${var}=$(skate get "${key}" 2>/dev/null)"
  done
}

# Only executed when run directly (e.g. `./direnv-skate.sh -h`), never when sourced by direnvrc
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  set -euo pipefail

  while getopts h flag; do
    case "${flag}" in
      h | *)
        print_help
        exit 0;;
    esac
  done

  print_help
fi

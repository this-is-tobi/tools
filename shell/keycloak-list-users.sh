#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Defaults
KC_USERNAME="admin"
KC_HOST=""
KC_PASSWORD="${KC_PASSWORD:-}"
KC_REALM=""

# Script helper
TEXT_HELPER="
The purpose of this script is to list users in a keycloak realm.

A password passed with -p is visible in the process list and the shell
history: prefer the KC_PASSWORD environment variable.

Available flags:
  -k    Keycloak host.
  -p    Keycloak password (or KC_PASSWORD environment variable).
  -r    Keycloak realm where to list users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  read -rsp 'Password: ' KC_PASSWORD && export KC_PASSWORD
  ./keycloak-list-users.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# The password is read by curl from stdin, never from its arguments.
get_token() {
  printf '%s' "$KC_PASSWORD" | curl -fsSL \
    -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=$KC_USERNAME" \
    --data-urlencode "password@-" \
    --data-urlencode "grant_type=password" | jq -r '.access_token // empty'
}

# Calls the realm admin API; the bearer token is passed through a file descriptor.
kc_api() {
  local method="$1"
  local path="$2"
  shift 2
  curl -fsSL -X "$method" "$KC_HOST/admin/realms/$KC_REALM$path" \
    -H @<(printf 'Authorization: Bearer %s\n' "$ACCESS_TOKEN") \
    "$@"
}

# Parse options
while getopts hk:p:r:u: flag; do
  case "${flag}" in
    k)
      KC_HOST=${OPTARG};;
    p)
      KC_PASSWORD=${OPTARG};;
    r)
      KC_REALM=${OPTARG};;
    u)
      KC_USERNAME=${OPTARG};;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Anything left after the flags is a mistake (getopts stops at the first non-option)
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  printf "Unexpected argument: '%s'.\n" "$1" >&2
  print_help >&2
  exit 1
fi

# Settings
printf "
Settings:
  > KC_HOST: ${KC_HOST}
  > KC_REALM: ${KC_REALM}
  > KC_USERNAME: ${KC_USERNAME}
"

# Options validation
if [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k).\n" >&2
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: user password (KC_PASSWORD or flag -p).\n" >&2
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r).\n" >&2
  exit 1
fi

# Init
if ! ACCESS_TOKEN="$(get_token)" || [ -z "$ACCESS_TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get an access token.\n" >&2
  exit 1
fi

# List users
kc_api GET "/users?max=-1" | jq '.'

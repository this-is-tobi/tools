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
KC_USERS=""

# Script helper
TEXT_HELPER="
The purpose of this script is to create users in a keycloak realm.

Flags are visible in the process list and the shell history: prefer the
KC_PASSWORD environment variable for the admin password, and pass users that
carry credentials from a file ('-d @users.json') or from stdin ('-d -').

Available flags:
  -d    JSON array of users to add, '@<file>' to read it from a file or '-' to read it from stdin.
  -k    Keycloak host.
  -p    Keycloak password (or KC_PASSWORD environment variable).
  -r    Keycloak realm where to add users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  read -rsp 'Password: ' KC_PASSWORD && export KC_PASSWORD
  ./keycloak-add-users.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -d @users.json

  With 'users.json' containing:
  [{\"username\":\"user1\",\"enabled\":true,\"credentials\":[{\"type\":\"password\",\"value\":\"pass1\",\"temporary\":false}]}]
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Prints the JSON given inline, from '@<file>' or from stdin ('-').
read_json() {
  case "$1" in
    -) cat;;
    @*) cat -- "${1#@}";;
    *) printf '%s' "$1";;
  esac
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
while getopts hd:k:p:r:u: flag; do
  case "${flag}" in
    d)
      KC_USERS=${OPTARG};;
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
# The users payload may hold passwords: it is never printed.
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
elif [ -z "$KC_USERS" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: users (flag -d).\n" >&2
  exit 1
fi

KC_USERS="$(read_json "$KC_USERS")"
if ! jq -e 'type == "array"' > /dev/null 2>&1 <<< "$KC_USERS"; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Users (flag -d) must be a JSON array.\n" >&2
  exit 1
fi

# Init
if ! ACCESS_TOKEN="$(get_token)" || [ -z "$ACCESS_TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get an access token.\n" >&2
  exit 1
fi

# Add users
# One compact JSON document per line, read on its own descriptor so curl cannot consume the list.
FAILED=0
while IFS= read -r USER_JSON <&3; do
  USERNAME=$(jq -r '.username // empty' <<< "$USER_JSON")

  if printf '%s' "$USER_JSON" | kc_api POST "/users" -H "Content-Type: application/json" --data-binary @- > /dev/null; then
    printf "User '%s' created successfully in realm '%s'.\n" "$USERNAME" "$KC_REALM"
  else
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to create user '%s'.\n" "$USERNAME" >&2
    FAILED=$((FAILED + 1))
  fi
done 3< <(jq -c '.[]' <<< "$KC_USERS")

if [ "$FAILED" -gt 0 ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} %s user(s) could not be created.\n" "$FAILED" >&2
  exit 1
fi

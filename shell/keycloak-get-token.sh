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
CLIENT_ID=""
CLIENT_SECRET="${KC_CLIENT_SECRET:-}"

# Script helper
TEXT_HELPER="
The purpose of this script is to display the keycloak user's token based on appropriate information.

Secrets passed as flags are visible in the process list and the shell history:
prefer the KC_PASSWORD and KC_CLIENT_SECRET environment variables.

Available flags:
  -i    Keycloak client id.
  -k    Keycloak host.
  -p    User password (or KC_PASSWORD environment variable).
  -r    Keycloak realm.
  -s    Keycloak client secret (or KC_CLIENT_SECRET environment variable).
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  read -rsp 'Password: ' KC_PASSWORD; read -rsp 'Client secret: ' KC_CLIENT_SECRET
  export KC_PASSWORD KC_CLIENT_SECRET
  ./keycloak-get-token.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -i 'my-client' \\
    -u 'admin'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

jwt_decode(){
  jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
}

# Secrets are read by curl from stdin and from a file descriptor, never from its arguments.
get_token() {
  printf '%s' "$KC_PASSWORD" | curl -fsSL \
    -X POST "$KC_HOST/realms/$KC_REALM/protocol/openid-connect/token" \
    --data-urlencode "grant_type=password" \
    --data-urlencode "client_id=$CLIENT_ID" \
    --data-urlencode client_secret@<(printf '%s' "$CLIENT_SECRET") \
    --data-urlencode "username=$KC_USERNAME" \
    --data-urlencode "password@-" | jq -r '.access_token // empty'
}

# Parse options
while getopts hi:k:p:r:s:u: flag; do
  case "${flag}" in
    i)
      CLIENT_ID=${OPTARG};;
    k)
      KC_HOST=${OPTARG};;
    p)
      KC_PASSWORD=${OPTARG};;
    r)
      KC_REALM=${OPTARG};;
    s)
      CLIENT_SECRET=${OPTARG};;
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
  > CLIENT_ID: ${CLIENT_ID}
  > CLIENT_SECRET: $([ -n "$CLIENT_SECRET" ] && echo set || echo unset)
"

# Options validation
if [ -z "$CLIENT_ID" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: client id (flag -i).\n" >&2
  exit 1
elif [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k).\n" >&2
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: user password (KC_PASSWORD or flag -p).\n" >&2
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r).\n" >&2
  exit 1
elif [ -z "$CLIENT_SECRET" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: client secret (KC_CLIENT_SECRET or flag -s).\n" >&2
  exit 1
elif [ -z "$KC_USERNAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: username (flag -u).\n" >&2
  exit 1
fi

# Init
if ! ACCESS_TOKEN="$(get_token)" || [ -z "$ACCESS_TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get an access token.\n" >&2
  exit 1
fi

# Display token
jwt_decode "$ACCESS_TOKEN"

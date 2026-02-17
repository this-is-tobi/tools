#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
KC_USERNAME="admin"
KC_HOST=""
KC_PASSWORD=""
KC_REALM=""

# Script helper
TEXT_HELPER="
The purpose of this script is to list users in a keycloak realm.

Available flags:
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to list users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  ./keycloak-list-users.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -u 'admin'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
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
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > KC_HOST: ${KC_HOST}
  > KC_REALM: ${KC_REALM}
  > KC_USERNAME: ${KC_USERNAME}
"

# Options validation
if [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k)".
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: user password (flag -p)".
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r)".
  exit 1
fi

# Init
ACCESS_TOKEN=$(curl -fsSL \
  -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=$KC_USERNAME" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

# List users
curl -fsSL \
  -X GET "$KC_HOST/admin/realms/$KC_REALM/users?max=-1" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.'

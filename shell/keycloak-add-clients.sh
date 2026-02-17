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
KC_CLIENTS=""

# Script helper
TEXT_HELPER="
The purpose of this script is to create multiple clients in a Keycloak realm.

Available flags:
  -c    JSON array of client configurations.
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to add the clients.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  ./keycloak-add-clients.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -c '[{\"clientId\":\"client1\",\"enabled\":true},{\"clientId\":\"client2\",\"enabled\":true}]' \\
    -u 'admin'
"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:k:p:r:u: flag; do
  case "${flag}" in
    c)
      KC_CLIENTS=${OPTARG};;  # Expecting a JSON array
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
  > KC_CLIENTS: ${KC_CLIENTS}
"

# Options validation
if [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k)."
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: admin password (flag -p)."
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r)."
  exit 1
elif [ -z "$KC_CLIENTS" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: client configurations (flag -c)."
  exit 1
fi

# Init
ACCESS_TOKEN=$(curl -fsSL \
  -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=$KC_USERNAME" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

# Add clients
for CLIENT in $(echo "$KC_CLIENTS" | jq -c '.[]'); do
  CLIENT_ID=$(echo "$CLIENT" | jq -r '.clientId')

  curl -fsSL \
    -X POST "$KC_HOST/admin/realms/$KC_REALM/clients" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$CLIENT"

  CLIENT_UUID=$(curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/clients?clientId=$CLIENT_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[0].id')

  if [ "$CLIENT_UUID" != "null" ]; then
    printf "\nClient '$CLIENT_ID' created successfully in realm '$KC_REALM'.\n"
  else
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to create client '$CLIENT_ID'.\n"
  fi
done
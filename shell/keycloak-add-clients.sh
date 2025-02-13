#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
KC_USERNAME="admin"

# Declare script helper
TEXT_HELPER="\nThe purpose of this script is to create multiple clients in a Keycloak realm.
Following flags are available:

  -c    JSON array of client configurations.
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to add the clients.
  -u    Keycloak username (Default is '$KC_USERNAME').
  -h    Print script help.\n\n"

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

if [ -z "$KC_HOST" ]; then
  printf "\n${red}Error.${no_color} Argument missing: keycloak host (flag -k)."
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${red}Error.${no_color} Argument missing: admin password (flag -p)."
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${red}Error.${no_color} Argument missing: keycloak realm (flag -r)."
  exit 1
elif [ -z "$KC_CLIENTS" ]; then
  printf "\n${red}Error.${no_color} Argument missing: client configurations (flag -c)."
  exit 1
fi

ACCESS_TOKEN=$(curl -fsSL \
  -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=$KC_USERNAME" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

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
    printf "\n${red}Error.${no_color} Failed to create client '$CLIENT_ID'.\n"
  fi
done
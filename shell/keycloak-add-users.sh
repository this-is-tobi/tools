#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
KC_USERNAME="admin"

# Script helper
TEXT_HELPER="The purpose of this script is to create users in a keycloak realm.

Available flags:
  -d    JSON array of users to add.
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to add users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  ./keycloak-add-users.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -d '[{\"username\":\"user1\",\"enabled\":true,\"credentials\":[{\"type\":\"password\",\"value\":\"pass1\",\"temporary\":false}]},{\"username\":\"user2\",\"enabled\":true,\"credentials\":[{\"type\":\"password\",\"value\":\"pass2\",\"temporary\":false}]}]' \\
    -u 'admin'
"

print_help() {
  printf "$TEXT_HELPER"
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
  > KC_USERS: ${KC_CLIENTS}
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
elif [ -z "$KC_USERS" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: users (flag -d)".
  exit 1
fi

# Init
ACCESS_TOKEN=$(curl -fsSL \
  -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

# Add users
for USER in $(echo "$KC_USERS" | jq -c '.[]'); do
  USERNAME=$(echo "$USER" | jq -r '.username')

  curl -fsSL \
    -X POST "$KC_HOST/admin/realms/$KC_REALM/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$USER"

  USER_UUID=$(curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?username=$USERNAME" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[0].id')

  if [ "$USER_UUID" != "null" ]; then
    printf "\User '$USERNAME' created successfully in realm '$KC_REALM'.\n"
  else
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to create user '$USERNAME'.\n"
  fi
done

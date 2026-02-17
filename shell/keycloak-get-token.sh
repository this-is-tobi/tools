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
CLIENT_ID=""
CLIENT_SECRET=""

# Script helper
TEXT_HELPER="
The purpose of this script is to display the keycloak user's token based on appropriate information.

Available flags:
  -i    Keycloak client id.
  -k    Keycloak host.
  -p    User password.
  -r    Keycloak realm.
  -s    Keycloak client secret.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  ./keycloak-get-token.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -i 'my-client' \\
    -s 'client-secret' \\
    -u 'admin'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

jwt_decode(){
  jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
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
  > CLIENT_ID: ${CLIENT_ID}
  > CLIENT_SECRET: $(printf "%*s" $(( ${#CLIENT_SECRET} - 3 )) "" | tr " " "*"; echo ${CLIENT_SECRET: -3};)
"

# Options validation
if [ -z "$CLIENT_ID" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: client id (flag -i)".
  exit 1
elif [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k)".
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: user password (flag -p)".
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r)".
  exit 1
elif [ -z "$CLIENT_SECRET" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: client secret (flag -s)".
  exit 1
elif [ -z "$KC_USERNAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: username (flag -u)".
  exit 1
fi

# Init
ACCESS_TOKEN=$(curl -fsSL \
  -X GET "$KC_HOST/realms/$KC_REALM/protocol/openid-connect/token" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$KC_USERNAME" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

# Display token
jwt_decode "$ACCESS_TOKEN"

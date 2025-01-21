#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
KC_USERNAME="admin"


# Declare script helper
TEXT_HELPER="\nThe purpose of this script is to create users in a keycloak realm.
Following flags are available:

  -d    JSON array of users to add.

  -k    Keycloak host.

  -p    Keycloak password.

  -r    Keycloak realm where to add users.

  -u    Keycloak username (Default is '$KC_USERNAME').

  -h    Print script help.\n\n"

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


if [ -z "$KC_HOST" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak host (flag -k)".
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${red}Error.${no_color} Argument missing : user password (flag -p)".
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak realm (flag -r)".
  exit 1
elif [ -z "$KC_USERS" ]; then
  printf "\n${red}Error.${no_color} Argument missing : users (flag -d)".
  exit 1
fi


ACCESS_TOKEN=$(curl -fsSL \
  -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

for USER in $(echo "$USERS" | jq -c '.[]'); do 
  DATA="{ 
    \"username\": \"$(echo $USER | jq -r '.username')\", 
    \"firstName\": \"$(echo $USER | jq -r '.firstName')\", 
    \"lastName\": \"$(echo $USER | jq -r '.lastName')\", 
    \"email\": \"$(echo $USER | jq -r '.email')\", 
    \"emailVerified\": true,
    \"enabled\": true,
    \"credentials\": [{
      \"type\": \"password\",
      \"value\": \"$(echo $USER | jq -r '.password')\",
      \"temporary\": false
    }]
  }"
  echo "$DATA"
  curl -fsSL \
    -X POST "$KC_HOST/admin/realms/$KC_REALM/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$DATA"
done

#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Declare script helper
TEXT_HELPER="\nThe purpose of this script is to create users in a keycloak realm.
Following flags are available:

  -k    Keycloak host.

  -p    Keycloak admin password.

  -r    Keycloak realm where to add users.

  -u    JSON array of users to add.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}


# Parse options
while getopts hk:p:r:u: flag; do
  case "${flag}" in
    k)
      KEYCLOAK_HOST=${OPTARG};;
    p)
      PASSWORD=${OPTARG};;
    r)
      REALM=${OPTARG};;
    u)
      USERS=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done


if [ -z "$KEYCLOAK_HOST" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak host (flag -k)".
  exit 1
elif [ -z "$PASSWORD" ]; then
  printf "\n${red}Error.${no_color} Argument missing : user password (flag -p)".
  exit 1
elif [ -z "$REALM" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak realm (flag -r)".
  exit 1
elif [ -z "$USERS" ]; then
  printf "\n${red}Error.${no_color} Argument missing : users (flag -u)".
  exit 1
fi


ACCESS_TOKEN=$(curl \
  -X POST "$KEYCLOAK_HOST/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

for user in $(echo "$USERS" | jq -c '.[]'); do 
  DATA="{ 
    \"username\": \"$(echo $user | jq -r '.username')\", 
    \"firstName\": \"$(echo $user | jq -r '.firstName')\", 
    \"lastName\": \"$(echo $user | jq -r '.lastName')\", 
    \"email\": \"$(echo $user | jq -r '.email')\", 
    \"emailVerified\": true,
    \"enabled\": true,
    \"credentials\": [{
      \"type\": \"password\",
      \"value\": \"$(echo $user | jq -r '.password')\",
      \"temporary\": false
    }]
  }"
  echo "$DATA"
  curl \
    -X POST "$KEYCLOAK_HOST/admin/realms/$REALM/users" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -d "$DATA"
done

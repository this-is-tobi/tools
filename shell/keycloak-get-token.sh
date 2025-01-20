#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Default
KC_USERNAME="admin"


# Declare script helper
TEXT_HELPER="\nThe purpose of this script is to display the keycloak user's token based on appropriate information.
Following flags are available:

  -i    Keycloak client id.

  -k    Keycloak host.

  -p    User password.

  -r    Keycloak realm.

  -s    Keycloak client secret.

  -u    Keycloak username (Default is '$KC_USERNAME').

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
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


function jwt_decode(){
  jq -R 'split(".") | .[1] | @base64d | fromjson' <<< "$1"
}

if [ -z "$CLIENT_ID" ]; then
  printf "\n${red}Error.${no_color} Argument missing : client id (flag -i)".
  exit 1
elif [ -z "$KC_HOST" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak host (flag -k)".
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${red}Error.${no_color} Argument missing : user password (flag -p)".
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${red}Error.${no_color} Argument missing : keycloak realm (flag -r)".
  exit 1
elif [ -z "$CLIENT_SECRET" ]; then
  printf "\n${red}Error.${no_color} Argument missing : client secret (flag -s)".
  exit 1
elif [ -z "$KC_USERNAME" ]; then
  printf "\n${red}Error.${no_color} Argument missing : username (flag -u)".
  exit 1
fi


ACCESS_TOKEN=$(curl \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "username=$KC_USERNAME" \
  -d "password=$KC_PASSWORD" \
  -d "grant_type=password" \
  "$KC_HOST/realms/$KC_REALM/protocol/openid-connect/token" | jq -r '.access_token')

jwt_decode "$ACCESS_TOKEN"

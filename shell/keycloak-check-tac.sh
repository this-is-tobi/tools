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
KC_BATCH_SIZE=500
KC_HOST=""
KC_PASSWORD=""
KC_REALM=""

# Script helper
TEXT_HELPER="
The purpose of this script is to check how many users have accepted terms and conditions in a keycloak realm.

Available flags:
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to list users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -b    Batch size for pagination (number of users per request).
        Default: '$KC_BATCH_SIZE'.
  -h    Print script help.

Example:
  ./keycloak-check-tac.sh \\
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
while getopts b:hk:p:r:u: flag; do
  case "${flag}" in
    k)
      KC_HOST=${OPTARG};;
    p)
      KC_PASSWORD=${OPTARG};;
    r)
      KC_REALM=${OPTARG};;
    u)
      KC_USERNAME=${OPTARG};;
    b)
      KC_BATCH_SIZE=${OPTARG};;
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
  > KC_BATCH_SIZE: ${KC_BATCH_SIZE}
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

# Get total count first
TOTAL=$(curl -fsSL \
  -X GET "$KC_HOST/admin/realms/$KC_REALM/users/count" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

printf "\n${COLOR_BLUE}Total users in realm:${COLOR_OFF} $TOTAL\n"
printf "Counting users with T&C acceptance (this may take a while for large realms)...\n"

# Count with pagination
ACCEPTED=0
PENDING=0
FIRST=0

while [ $FIRST -lt $TOTAL ]; do
  BATCH_END=$((FIRST + KC_BATCH_SIZE - 1))
  if [ "$BATCH_END" -ge "$TOTAL" ]; then
    BATCH_END=$((TOTAL - 1))
  fi
  
  printf "${COLOR_BLUE}Processing users ${FIRST}-${BATCH_END}...${COLOR_OFF}\n"
  
  # Refresh token before each batch to avoid expiration
  ACCESS_TOKEN=$(curl -fsSL \
    -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=$KC_USERNAME" \
    -d "password=$KC_PASSWORD" \
    -d "grant_type=password" | jq -r '.access_token')
  
  BATCH=$(curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?first=$FIRST&max=$KC_BATCH_SIZE" \
    -H "Authorization: Bearer $ACCESS_TOKEN")
  
  BATCH_ACCEPTED=$(echo "$BATCH" | jq '[.[] | select(.attributes.terms_and_conditions)] | length')
  BATCH_PENDING=$(echo "$BATCH" | jq '[.[] | select(.requiredActions // [] | any(. == "TERMS_AND_CONDITIONS"))] | length')
  
  ACCEPTED=$((ACCEPTED + BATCH_ACCEPTED))
  PENDING=$((PENDING + BATCH_PENDING))
  FIRST=$((FIRST + KC_BATCH_SIZE))
done

NOT_ACCEPTED=$((TOTAL - ACCEPTED))

printf "\n${COLOR_GREEN}=== Summary ===${COLOR_OFF}\n"
printf "  - Total users: ${COLOR_BLUE}$TOTAL${COLOR_OFF}\n"
printf "  - Accepted T&C: ${COLOR_GREEN}$ACCEPTED${COLOR_OFF}\n"
printf "  - Not accepted T&C: ${COLOR_YELLOW}$NOT_ACCEPTED${COLOR_OFF}\n"
printf "  - T&C pending action: ${COLOR_YELLOW}$PENDING${COLOR_OFF}\n"
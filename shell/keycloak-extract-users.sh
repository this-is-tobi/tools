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
KC_BATCH_SIZE=100
KC_OUTPUT_FILE="keycloak_users_$(date +%Y%m%d_%H%M%S).csv"

# Script helper
TEXT_HELPER="
The purpose of this script is to extract all users from a keycloak realm to a CSV file.

Available flags:
  -b    Batch size for user extraction.
        Default: '$KC_BATCH_SIZE'.
  -k    Keycloak host.
  -o    Output CSV file path.
        Default: '$KC_OUTPUT_FILE'.
  -p    Keycloak password.
  -r    Keycloak realm to extract users from.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  ./keycloak-extract-users.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -b 100 \\
    -o 'users.csv'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

get_token() {
  curl -fsSL \
    -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=$KC_USERNAME" \
    -d "password=$KC_PASSWORD" \
    -d "grant_type=password" | jq -r '.access_token'
}

get_users_batch() {
  local first=$1
  local max=$2
  
  curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?first=${first}&max=${max}" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json"
}

extract_user_data() {
  local user_json=$1
  
  echo "$user_json" | jq -r '.[] | 
    [
      .firstName // "",
      .lastName // "",
      .email // "",
      (.attributes.termsAccepted[0] // .attributes.terms_and_conditions[0] // .attributes.TnC[0] // "not_set"),
      .id,
      .username,
      (.enabled | tostring),
      (.emailVerified | tostring)
    ] | @csv' >> "$KC_OUTPUT_FILE"
}

# Parse options
while getopts hb:k:o:p:r:u: flag; do
  case "${flag}" in
    b)
      KC_BATCH_SIZE=${OPTARG};;
    k)
      KC_HOST=${OPTARG};;
    o)
      KC_OUTPUT_FILE=${OPTARG};;
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
  > KC_BATCH_SIZE: ${KC_BATCH_SIZE}
  > KC_OUTPUT_FILE: ${KC_OUTPUT_FILE}
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
ACCESS_TOKEN=$(get_token)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get access token.\n"
  exit 1
fi

# Create CSV header
echo "FirstName,LastName,Email,TermsAndConditionsStatus,UserID,Username,Enabled,EmailVerified" > "$KC_OUTPUT_FILE"

# Extract users
first=0
total_users=0
batch_count=0

printf "\n${COLOR_YELLOW}Starting user extraction...${COLOR_OFF}\n"

while true; do
  batch_count=$((batch_count + 1))
  printf "${COLOR_BLUE}Fetching batch ${batch_count} (users ${first} to $((first + KC_BATCH_SIZE)))...${COLOR_OFF}\n"
  
  users_json=$(get_users_batch "$first" "$KC_BATCH_SIZE")
  user_count=$(echo "$users_json" | jq '. | length')
  
  if [ "$user_count" -eq 0 ]; then
    printf "${COLOR_GREEN}No more users to fetch${COLOR_OFF}\n"
    break
  fi
  
  extract_user_data "$users_json"
  
  total_users=$((total_users + user_count))
  printf "${COLOR_GREEN}Processed ${user_count} users (Total: ${total_users})${COLOR_OFF}\n"
  
  if [ "$user_count" -lt "$KC_BATCH_SIZE" ]; then
    printf "${COLOR_GREEN}Reached end of user list${COLOR_OFF}\n"
    break
  fi
  
  first=$((first + KC_BATCH_SIZE))
  sleep 0.5
done

printf "\n${COLOR_GREEN}=== Export Complete ===${COLOR_OFF}\n"
printf "Total users exported: ${total_users}\n"
printf "Output file: ${KC_OUTPUT_FILE}\n"

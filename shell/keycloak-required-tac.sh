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
KC_FORCE_ALL=false
KC_BATCH_SIZE=100

# Script helper
TEXT_HELPER="
The purpose of this script is to force users to accept terms and conditions in a keycloak realm.

Available flags:
  -k    Keycloak host.
  -p    Keycloak password.
  -r    Keycloak realm where to list users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -b    Batch size for pagination (number of users per request).
        Default: '$KC_BATCH_SIZE'.
  -f    Force all users to accept T&C (even those who already accepted).
        Use this when T&C have been updated.
        Default: false (only users who haven't accepted).
  -h    Print script help.

Example:
  # Force only users who haven't accepted T&C
  ./keycloak-required-tac.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -u 'admin'

  # Force ALL users (e.g., after T&C update)
  ./keycloak-required-tac.sh \\
    -k 'http://localhost:8080' \\
    -p 'admin' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -f
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts b:fhk:p:r:u: flag; do
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
    f)
      KC_FORCE_ALL=true;;
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
  > KC_FORCE_ALL: ${KC_FORCE_ALL}
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

# Get total user count first
TOTAL_USERS=$(curl -fsSL \
  -X GET "$KC_HOST/admin/realms/$KC_REALM/users/count" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

printf "\n${COLOR_BLUE}Total users in realm:${COLOR_OFF} $TOTAL_USERS\n"

# Process users in batches
UPDATED_COUNT=0
SKIPPED_COUNT=0
PROCESSED_COUNT=0
FIRST=0

while true; do
  BATCH_END=$((FIRST + KC_BATCH_SIZE - 1))
  if [ "$BATCH_END" -gt "$TOTAL_USERS" ]; then
    BATCH_END=$TOTAL_USERS
  fi
  
  printf "\n${COLOR_BLUE}Fetching users ${FIRST}-${BATCH_END}...${COLOR_OFF}\n"
  
  USERS=$(curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?first=$FIRST&max=$KC_BATCH_SIZE" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ACCESS_TOKEN" | jq -c '.')
  
  BATCH_COUNT=$(echo "$USERS" | jq 'length')
  
  # Exit if no more users
  if [ "$BATCH_COUNT" -eq 0 ]; then
    break
  fi

  for USER in $(echo "$USERS" | jq -c '.[]'); do
    USERNAME=$(echo "$USER" | jq -r '.username')
    USER_ID=$(echo "$USER" | jq -r '.id')
    ATTRIBUTES=$(echo "$USER" | jq -r '.attributes // {}')
    HAS_ACCEPTED_TAC=$(echo "$ATTRIBUTES" | jq 'has("terms_and_conditions")')
    REQUIRED_ACTIONS=$(echo "$USER" | jq -r '.requiredActions // []')
    HAS_TAC_PENDING=$(echo "$REQUIRED_ACTIONS" | jq 'any(. == "TERMS_AND_CONDITIONS")')
    
    if [ "$KC_FORCE_ALL" = true ]; then
      # Force all users to accept T&C (even those who already accepted)
      printf "${COLOR_BLUE}Processing user:${COLOR_OFF} $USERNAME (force all mode)\n"
      curl -fsSL \
        -X PUT "$KC_HOST/admin/realms/$KC_REALM/users/$USER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -d '{"requiredActions": ["TERMS_AND_CONDITIONS"]}'
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    elif [ "$HAS_ACCEPTED_TAC" = false ] && [ "$HAS_TAC_PENDING" = false ]; then
      # User has NOT accepted T&C and doesn't have pending action
      printf "${COLOR_YELLOW}Processing user:${COLOR_OFF} $USERNAME (user never accepted T&C)\n"
      
      # Get current required actions and add TERMS_AND_CONDITIONS
      NEW_ACTIONS=$(echo "$REQUIRED_ACTIONS" | jq '. + ["TERMS_AND_CONDITIONS"] | unique')
      
      curl -fsSL \
        -X PUT "$KC_HOST/admin/realms/$KC_REALM/users/$USER_ID" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -d "{\"requiredActions\": $NEW_ACTIONS}"
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
      # User has already accepted T&C or has pending action
      if [ "$HAS_ACCEPTED_TAC" = true ]; then
        printf "${COLOR_GREEN}Skipping user:${COLOR_OFF} $USERNAME (already accepted T&C)\n"
      else
        printf "${COLOR_GREEN}Skipping user:${COLOR_OFF} $USERNAME (T&C already pending)\n"
      fi
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
  done
  
  # Move to next batch
  FIRST=$((FIRST + KC_BATCH_SIZE))
done

printf "\n${COLOR_GREEN}Summary:${COLOR_OFF}\n"
printf "  - Total users in realm: $TOTAL_USERS\n"
printf "  - Processed: $PROCESSED_COUNT\n"
printf "  - Updated: $UPDATED_COUNT\n"
printf "  - Skipped: $SKIPPED_COUNT\n"

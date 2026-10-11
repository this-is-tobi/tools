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
KC_FORCE_ALL=false
KC_BATCH_SIZE=100
KC_DRY_RUN=false
KC_HOST=""
KC_PASSWORD="${KC_PASSWORD:-}"
KC_REALM=""

# Script helper
TEXT_HELPER="
The purpose of this script is to force users to accept terms and conditions in a keycloak realm.

Available flags:
  -k    Keycloak host.
  -p    Keycloak password (or KC_PASSWORD environment variable).
  -r    Keycloak realm where to list users.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -b    Batch size for pagination (number of users per request).
        Default: '$KC_BATCH_SIZE'.
  -f    Force all users to accept T&C (even those who already accepted).
        Use this when T&C have been updated.
        Default: false (only users who haven't accepted).
  -d    Dry run mode. Show what would be updated without making any changes.
        Default: false.
  -h    Print script help.

Example:
  read -rsp 'Password: ' KC_PASSWORD && export KC_PASSWORD

  # Dry run to preview changes
  ./keycloak-required-tac.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -d

  # Force only users who haven't accepted T&C
  ./keycloak-required-tac.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin'

  # Force ALL users (e.g., after T&C update)
  ./keycloak-required-tac.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -f
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# The password is read by curl from stdin, never from its arguments.
get_token() {
  printf '%s' "$KC_PASSWORD" | curl -fsSL \
    -X POST "$KC_HOST/realms/master/protocol/openid-connect/token" \
    --data-urlencode "client_id=admin-cli" \
    --data-urlencode "username=$KC_USERNAME" \
    --data-urlencode "password@-" \
    --data-urlencode "grant_type=password" | jq -r '.access_token // empty'
}

refresh_token() {
  if ! ACCESS_TOKEN="$(get_token)" || [ -z "$ACCESS_TOKEN" ]; then
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get an access token.\n" >&2
    exit 1
  fi
}

# Prints the Authorization header; curl reads it through a file descriptor so the token stays out of its arguments.
auth_header() {
  printf 'Authorization: Bearer %s\n' "$ACCESS_TOKEN"
}

# Parse options
while getopts b:dfhk:p:r:u: flag; do
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
    d)
      KC_DRY_RUN=true;;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Anything left after the flags is a mistake (getopts stops at the first non-option)
shift $((OPTIND - 1))
if [ $# -gt 0 ]; then
  printf "Unexpected argument: '%s'.\n" "$1" >&2
  print_help >&2
  exit 1
fi

# Settings
printf "
Settings:
  > KC_HOST: ${KC_HOST}
  > KC_REALM: ${KC_REALM}
  > KC_USERNAME: ${KC_USERNAME}
  > KC_BATCH_SIZE: ${KC_BATCH_SIZE}
  > KC_FORCE_ALL: ${KC_FORCE_ALL}
  > KC_DRY_RUN: ${KC_DRY_RUN}
"

# Options validation
if [ -z "$KC_HOST" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak host (flag -k).\n" >&2
  exit 1
elif [ -z "$KC_PASSWORD" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: user password (KC_PASSWORD or flag -p).\n" >&2
  exit 1
elif [ -z "$KC_REALM" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: keycloak realm (flag -r).\n" >&2
  exit 1
elif ! [ "$KC_BATCH_SIZE" -gt 0 ] 2>/dev/null; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Batch size (flag -b) must be a positive integer.\n" >&2
  exit 1
fi

# Init
refresh_token

# Get total user count first
TOTAL_USERS=$(curl -fsSL \
  -X GET "$KC_HOST/admin/realms/$KC_REALM/users/count" \
  -H @<(auth_header))

printf "\n${COLOR_BLUE}Total users in realm:${COLOR_OFF} $TOTAL_USERS\n"

if [ "$KC_DRY_RUN" = true ]; then
  printf "\n${COLOR_YELLOW}DRY RUN MODE - No changes will be made${COLOR_OFF}\n"
fi

# Process users in batches
UPDATED_COUNT=0
SKIPPED_COUNT=0
PROCESSED_COUNT=0
FIRST=0

while true; do
  # Exit condition: check if we've processed all users
  if [ "$FIRST" -ge "$TOTAL_USERS" ]; then
    break
  fi
  
  BATCH_END=$((FIRST + KC_BATCH_SIZE - 1))
  if [ "$BATCH_END" -ge "$TOTAL_USERS" ]; then
    BATCH_END=$((TOTAL_USERS - 1))
  fi
  
  printf "\n${COLOR_BLUE}Fetching users ${FIRST}-${BATCH_END}...${COLOR_OFF}\n"
  
  # Refresh token before each batch to avoid expiration
  refresh_token
  
  USERS=$(curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?first=$FIRST&max=$KC_BATCH_SIZE" \
    -H "Content-Type: application/json" \
    -H @<(auth_header))
  
  # Check if curl succeeded and returned valid JSON
  if [ -z "$USERS" ] || [ "$USERS" = "null" ]; then
    printf "${COLOR_RED}Error fetching users or empty response${COLOR_OFF}\n"
    break
  fi
  
  BATCH_COUNT=$(echo "$USERS" | jq 'length // 0')
  
  # Exit if no more users
  if [ "$BATCH_COUNT" -eq 0 ]; then
    break
  fi

  # Process each user using base64 encoding to avoid word splitting issues
  while IFS= read -r USER_B64; do
    USER=$(echo "$USER_B64" | base64 --decode)
    USERNAME=$(echo "$USER" | jq -r '.username')
    USER_ID=$(echo "$USER" | jq -r '.id')
    ATTRIBUTES=$(echo "$USER" | jq -c '.attributes // {}')
    HAS_ACCEPTED_TAC=$(echo "$ATTRIBUTES" | jq 'has("terms_and_conditions")')
    REQUIRED_ACTIONS=$(echo "$USER" | jq -c '.requiredActions // []')
    HAS_TAC_PENDING=$(echo "$REQUIRED_ACTIONS" | jq 'any(. == "TERMS_AND_CONDITIONS")')
    
    if [ "$KC_FORCE_ALL" = true ]; then
      # Force all users to accept T&C (even those who already accepted),
      # keeping the other actions they still have to complete
      printf "${COLOR_BLUE}Processing user:${COLOR_OFF} $USERNAME (ID: $USER_ID) - force all mode\n"
      NEW_ACTIONS=$(echo "$REQUIRED_ACTIONS" | jq -c '. + ["TERMS_AND_CONDITIONS"] | unique')
      if [ "$KC_DRY_RUN" = false ]; then
        curl -fsSL \
          -X PUT "$KC_HOST/admin/realms/$KC_REALM/users/$USER_ID" \
          -H "Content-Type: application/json" \
          -H @<(auth_header) \
          -d "{\"requiredActions\": $NEW_ACTIONS}"
      else
        printf "  ${COLOR_BLUE}[DRY RUN]${COLOR_OFF} Would set requiredActions to %s\n" "$NEW_ACTIONS"
      fi
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    elif [ "$HAS_ACCEPTED_TAC" = false ] && [ "$HAS_TAC_PENDING" = false ]; then
      # User has NOT accepted T&C and doesn't have pending action
      printf "${COLOR_YELLOW}Processing user:${COLOR_OFF} $USERNAME (ID: $USER_ID) - never accepted T&C\n"
      
      # Get current required actions and add TERMS_AND_CONDITIONS
      NEW_ACTIONS=$(echo "$REQUIRED_ACTIONS" | jq -c '. + ["TERMS_AND_CONDITIONS"] | unique')
      
      if [ "$KC_DRY_RUN" = false ]; then
        curl -fsSL \
          -X PUT "$KC_HOST/admin/realms/$KC_REALM/users/$USER_ID" \
          -H "Content-Type: application/json" \
          -H @<(auth_header) \
          -d "{\"requiredActions\": $NEW_ACTIONS}"
      else
        printf "  ${COLOR_BLUE}[DRY RUN]${COLOR_OFF} Would set requiredActions to %s\n" "$NEW_ACTIONS"
      fi
      UPDATED_COUNT=$((UPDATED_COUNT + 1))
    else
      # User has already accepted T&C or has pending action
      if [ "$HAS_ACCEPTED_TAC" = true ]; then
        printf "${COLOR_GREEN}Skipping user:${COLOR_OFF} $USERNAME (ID: $USER_ID) - already accepted T&C\n"
      else
        printf "${COLOR_GREEN}Skipping user:${COLOR_OFF} $USERNAME (ID: $USER_ID) - T&C already pending\n"
      fi
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
    PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
  done < <(echo "$USERS" | jq -r '.[] | @base64')
  
  # Move to next batch
  FIRST=$((FIRST + KC_BATCH_SIZE))
done

printf "\n${COLOR_GREEN}Summary:${COLOR_OFF}\n"
if [ "$KC_DRY_RUN" = true ]; then
  printf "  ${COLOR_YELLOW}[DRY RUN MODE - No changes were made]${COLOR_OFF}\n"
fi
printf "  - Total users in realm: $TOTAL_USERS\n"
printf "  - Processed: $PROCESSED_COUNT\n"
if [ "$KC_DRY_RUN" = true ]; then
  printf "  - Would update: $UPDATED_COUNT\n"
else
  printf "  - Updated: $UPDATED_COUNT\n"
fi
printf "  - Skipped: $SKIPPED_COUNT\n"

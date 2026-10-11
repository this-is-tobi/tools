#!/bin/bash

set -euo pipefail

# The export holds personal data: keep it readable by the current user only.
umask 077

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
KC_HOST=""
KC_PASSWORD="${KC_PASSWORD:-}"
KC_REALM=""

# Script helper
TEXT_HELPER="
The purpose of this script is to extract all users from a keycloak realm to a CSV file.

The file is created readable by the current user only, and cells starting with
'=', '+', '-', '@', a tab or a carriage return are prefixed with a quote so
spreadsheet applications do not evaluate them as formulas.

A password passed with -p is visible in the process list and the shell
history: prefer the KC_PASSWORD environment variable.

Available flags:
  -b    Batch size for user extraction.
        Default: '$KC_BATCH_SIZE'.
  -k    Keycloak host.
  -o    Output CSV file path.
        Default: '$KC_OUTPUT_FILE'.
  -p    Keycloak password (or KC_PASSWORD environment variable).
  -r    Keycloak realm to extract users from.
  -u    Keycloak username.
        Default: '$KC_USERNAME'.
  -h    Print script help.

Example:
  read -rsp 'Password: ' KC_PASSWORD && export KC_PASSWORD
  ./keycloak-extract-users.sh \\
    -k 'http://localhost:8080' \\
    -r 'my-realm' \\
    -u 'admin' \\
    -b 100 \\
    -o 'users.csv'
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

# Admin tokens from the master realm live about a minute: a new one is fetched for every batch.
refresh_token() {
  if ! ACCESS_TOKEN="$(get_token)" || [ -z "$ACCESS_TOKEN" ]; then
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Failed to get an access token.\n" >&2
    exit 1
  fi
}

# The bearer token is passed through a file descriptor, never as an argument.
get_users_batch() {
  local first=$1
  local max=$2

  curl -fsSL \
    -X GET "$KC_HOST/admin/realms/$KC_REALM/users?first=${first}&max=${max}" \
    -H @<(printf 'Authorization: Bearer %s\n' "$ACCESS_TOKEN") \
    -H "Content-Type: application/json"
}

extract_user_data() {
  local user_json=$1

  echo "$user_json" | jq -r '
    def cell: if type == "string" and test("^[=+@\t\r-]") then "'"'"'" + . else . end;
    .[] |
    [
      .firstName // "",
      .lastName // "",
      .email // "",
      (.attributes.termsAccepted[0] // .attributes.terms_and_conditions[0] // .attributes.TnC[0] // "not_set"),
      .id,
      .username,
      (.enabled | tostring),
      (.emailVerified | tostring)
    ] | map(cell) | @csv' >> "$KC_OUTPUT_FILE"
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
  > KC_OUTPUT_FILE: ${KC_OUTPUT_FILE}
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

# Create CSV header
echo "FirstName,LastName,Email,TermsAndConditionsStatus,UserID,Username,Enabled,EmailVerified" > "$KC_OUTPUT_FILE"
# The umask only applies to new files: tighten an existing one too.
if [ -f "$KC_OUTPUT_FILE" ]; then
  chmod 600 "$KC_OUTPUT_FILE"
fi

# Extract users
first=0
total_users=0
batch_count=0

printf "\n${COLOR_YELLOW}Starting user extraction...${COLOR_OFF}\n"

while true; do
  batch_count=$((batch_count + 1))
  printf "${COLOR_BLUE}Fetching batch ${batch_count} (users ${first} to $((first + KC_BATCH_SIZE)))...${COLOR_OFF}\n"

  refresh_token
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

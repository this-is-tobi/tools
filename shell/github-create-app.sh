#!/bin/bash

set -e

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Helper text
TEXT_HELPER="
This script creates a GitHub App using the GitHub REST API.

Available flags:
  -n    Name of the GitHub App.
  -o    Owner (organization or user).
  -t    GitHub Personal Access Token.
  -d    Description of the app.
  -u    Homepage URL.
  -c    Callback URL.
  -p    Permissions (JSON string).
  -e    Events (comma-separated).
  -k    Create a private key for the app and include it in the final JSON output.
  -h    Print script help.

Example:
  ./github-create-app.sh \\
    -n 'MyApp' \\
    -o 'this-is-tobi' \\
    -t 'ghp_xxx' \\
    -d 'My app desc' \\
    -u 'https://example.com' \\
    -c 'https://example.com/callback' \\
    -p '{\"contents\":\"read\",\"issues\":\"write\"}' \\
    -e 'push,pull_request' \\
    -k
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
CREATE_KEY="false"
while getopts hn:o:t:d:u:c:p:e:k flag; do
  case "${flag}" in
    n)
      APP_NAME=${OPTARG};;
    o)
      OWNER=${OPTARG};;
    t)
      TOKEN=${OPTARG};;
    d)
      DESCRIPTION=${OPTARG};;
    u)
      HOMEPAGE_URL=${OPTARG};;
    c)
      CALLBACK_URL=${OPTARG};;
    p)
      PERMISSIONS=${OPTARG};;
    e)
      EVENTS=${OPTARG};;
    k)
      CREATE_KEY="true";;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > APP_NAME: $APP_NAME
  > OWNER: $OWNER
  > DESCRIPTION: $DESCRIPTION
  > HOMEPAGE_URL: $HOMEPAGE_URL
  > CALLBACK_URL: $CALLBACK_URL
  > PERMISSIONS: $PERMISSIONS
  > EVENTS: $EVENTS
  > CREATE_KEY: $CREATE_KEY
"

# Options validation
if [ -z "$APP_NAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: app name (flag -n).\n"
  exit 1
elif [ -z "$OWNER" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: owner (flag -o).\n"
  exit 1
elif [ -z "$TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: token (flag -t).\n"
  exit 1
fi


# Init
CREATE_URL="https://api.github.com/orgs/$OWNER/apps"


# Create default JSON
PAYLOAD=$(jq -n --arg name "$APP_NAME" --arg desc "$DESCRIPTION" '{name: $name, description: $desc, public: true}')

# Add fields if defined
if [ -n "$HOMEPAGE_URL" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg url "$HOMEPAGE_URL" '.url = $url')
fi
if [ -n "$CALLBACK_URL" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --arg cb "$CALLBACK_URL" '.callback_url = $cb')
fi
if [ -n "$PERMISSIONS" ]; then
  PAYLOAD=$(echo "$PAYLOAD" | jq --argjson perms "$PERMISSIONS" '.default_permissions = $perms')
fi
if [ -n "$EVENTS" ]; then
  EVENTS_JSON=$(jq -n --arg events "$EVENTS" '($events | split(","))')
  PAYLOAD=$(echo "$PAYLOAD" | jq --argjson ev "$EVENTS_JSON" '.default_events = $ev')
fi

printf "Creating GitHub App '$APP_NAME'...\n"

RESPONSE=$(curl -fsSL \
  -X POST "$CREATE_URL" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$PAYLOAD")

# After successful app creation, handle private key creation if requested
if echo "$RESPONSE" | jq -e '.id' > /dev/null; then
  if [ "$CREATE_KEY" = "true" ]; then
    APP_ID=$(echo "$RESPONSE" | jq -r '.id')
    KEY_URL="https://api.github.com/app/$APP_ID/keys"
    KEY_RESPONSE=$(curl -fsSL \
      -X POST "$KEY_URL" \
      -H "Authorization: token $TOKEN" \
      -H "Accept: application/vnd.github+json")
    # Merge private key info into the app response
    FINAL_RESPONSE=$(jq -s '.[0] + {private_key: .[1].key, key_id: .[1].id}' <(echo "$RESPONSE") <(echo "$KEY_RESPONSE"))
  else
    FINAL_RESPONSE=$(echo "$RESPONSE")
  fi
  printf "GitHub App created successfully.\n"
  echo "$FINAL_RESPONSE" | jq
else
  printf "Failed to create GitHub App.\n"
  echo "$FINAL_RESPONSE" | jq
  exit 1
fi

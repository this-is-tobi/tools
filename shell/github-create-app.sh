#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
APP_NAME=""
OWNER=""
DESCRIPTION=""
HOMEPAGE_URL=""
CALLBACK_URL=""
WEBHOOK_URL=""
PERMISSIONS=""
EVENTS=""
PUBLIC="false"
OUTPUT_FILE=""
# GitHub appends '?code=...&state=...' to this URL once the app is registered.
REDIRECT_URL="http://localhost/"

# Helper text
TEXT_HELPER="
This script creates a GitHub App with the GitHub App manifest flow.

GitHub has no API to create an app from a token: the app is registered from a
manifest in the browser, then the temporary code GitHub hands back is exchanged
for the app credentials. The script:
  1. writes the manifest into a local page that posts it to GitHub and opens it;
  2. asks for the address GitHub redirects to after you click 'Create GitHub App'
     (a 'http://localhost/?code=...' page that fails to load: copy its address);
  3. exchanges the code and saves the credentials (app id, client id and secret,
     webhook secret, private key) to a file readable by you only.
All three steps must be done within one hour.

Available flags:
  -n    Name of the GitHub App.
  -o    Owner (organization or user).
  -d    Description of the app.
  -u    Homepage URL.
        Default: 'https://github.com/<owner>'.
  -c    Callback URL.
  -w    Webhook URL (webhooks stay inactive without it).
  -p    Permissions (JSON string).
  -e    Events (comma-separated); GitHub only delivers them to an active webhook (-w).
  -P    Make the app public (installable by any account).
        Default: '$PUBLIC'.
  -f    File where the app credentials are saved.
        Default: 'github-app-<slug>.json'.
  -k    Kept for compatibility: the private key is always saved with the credentials.
  -t    Kept for compatibility: no token is needed.
  -h    Print script help.

Example:
  ./github-create-app.sh \\
    -n 'MyApp' \\
    -o 'this-is-tobi' \\
    -d 'My app desc' \\
    -u 'https://example.com' \\
    -c 'https://example.com/callback' \\
    -w 'https://example.com/webhook' \\
    -p '{\"contents\":\"read\",\"issues\":\"write\"}' \\
    -e 'push,pull_request'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Prints the value of a query parameter from a URL.
query_param() {
  printf '%s\n' "$1" | sed -n "s/.*[?&]$2=\([^&#]*\).*/\1/p"
}

# Parse options
while getopts hn:o:t:d:u:c:w:p:e:Pf:k flag; do
  case "${flag}" in
    n)
      APP_NAME=${OPTARG};;
    o)
      OWNER=${OPTARG};;
    t)
      printf "${COLOR_YELLOW}Warning.${COLOR_OFF} -t is ignored: the manifest flow needs no token.\n" >&2;;
    d)
      DESCRIPTION=${OPTARG};;
    u)
      HOMEPAGE_URL=${OPTARG};;
    c)
      CALLBACK_URL=${OPTARG};;
    w)
      WEBHOOK_URL=${OPTARG};;
    p)
      PERMISSIONS=${OPTARG};;
    e)
      EVENTS=${OPTARG};;
    P)
      PUBLIC="true";;
    f)
      OUTPUT_FILE=${OPTARG};;
    k)
      ;;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

HOMEPAGE_URL="${HOMEPAGE_URL:-https://github.com/$OWNER}"

# Settings
printf "
Settings:
  > APP_NAME: $APP_NAME
  > OWNER: $OWNER
  > DESCRIPTION: $DESCRIPTION
  > HOMEPAGE_URL: $HOMEPAGE_URL
  > CALLBACK_URL: $CALLBACK_URL
  > WEBHOOK_URL: $WEBHOOK_URL
  > PERMISSIONS: $PERMISSIONS
  > EVENTS: $EVENTS
  > PUBLIC: $PUBLIC
  > OUTPUT_FILE: ${OUTPUT_FILE:-github-app-<slug>.json}
"

# Options validation
if [ -z "$APP_NAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: app name (flag -n).\n" >&2
  exit 1
elif [ -z "$OWNER" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: owner (flag -o).\n" >&2
  exit 1
elif [ -n "$PERMISSIONS" ] && ! jq -e 'type == "object"' > /dev/null 2>&1 <<< "$PERMISSIONS"; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Permissions (flag -p) must be a JSON object.\n" >&2
  exit 1
fi

# Init
OWNER_TYPE="$(curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/users/$OWNER" | jq -r '.type // empty')" || true
if [ "$OWNER_TYPE" = "Organization" ]; then
  CREATE_URL="https://github.com/organizations/$OWNER/settings/apps/new"
elif [ "$OWNER_TYPE" = "User" ]; then
  CREATE_URL="https://github.com/settings/apps/new"
else
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Owner '%s' not found on Github.\n" "$OWNER" >&2
  exit 1
fi

# Build the manifest
MANIFEST=$(jq -n \
  --arg name "$APP_NAME" \
  --arg desc "$DESCRIPTION" \
  --arg url "$HOMEPAGE_URL" \
  --arg redirect "$REDIRECT_URL" \
  --argjson public "$PUBLIC" \
  '{name: $name, description: $desc, url: $url, redirect_url: $redirect, public: $public}')

if [ -n "$CALLBACK_URL" ]; then
  MANIFEST=$(jq --arg cb "$CALLBACK_URL" '.callback_urls = [$cb]' <<< "$MANIFEST")
fi
if [ -n "$WEBHOOK_URL" ]; then
  MANIFEST=$(jq --arg hook "$WEBHOOK_URL" '.hook_attributes = {url: $hook, active: true}' <<< "$MANIFEST")
fi
if [ -n "$PERMISSIONS" ]; then
  MANIFEST=$(jq --argjson perms "$PERMISSIONS" '.default_permissions = $perms' <<< "$MANIFEST")
fi
if [ -n "$EVENTS" ]; then
  MANIFEST=$(jq --arg events "$EVENTS" '.default_events = ($events | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))' <<< "$MANIFEST")
fi

# The state comes back with the code: checking it proves the code answers this request.
STATE="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/github-create-app.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
FORM_FILE="$WORK_DIR/create-app.html"

cat > "$FORM_FILE" <<EOF
<!doctype html>
<html>
  <body>
    <form id="manifest-form" action="$CREATE_URL?state=$STATE" method="post">
      <input type="hidden" name="manifest" value="$(jq -r 'tojson | @html' <<< "$MANIFEST")">
      <button type="submit">Register the GitHub App '$(jq -rn --arg x "$APP_NAME" '$x | @html')'</button>
    </form>
    <script>document.getElementById("manifest-form").submit();</script>
  </body>
</html>
EOF

printf "\nOpening the registration page (%s).\n" "$FORM_FILE"
if command -v open > /dev/null 2>&1; then
  open "$FORM_FILE"
elif command -v xdg-open > /dev/null 2>&1; then
  xdg-open "$FORM_FILE" > /dev/null 2>&1 &
else
  printf "Open it in your browser.\n"
fi

printf "\nClick 'Create GitHub App', then paste the address of the page GitHub redirects to\n(it starts with '%s?code='): " "$REDIRECT_URL"
# Read from the terminal so the prompt also works when the script itself comes from stdin.
read -r REDIRECTED_TO < /dev/tty

CODE="$(query_param "$REDIRECTED_TO" code)"
RETURNED_STATE="$(query_param "$REDIRECTED_TO" state)"
if [ -z "$CODE" ] || ! printf '%s' "$CODE" | grep -Eq '^[A-Za-z0-9_-]+$'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} No code found in '%s'.\n" "$REDIRECTED_TO" >&2
  exit 1
fi
if [ "$RETURNED_STATE" != "$STATE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} The state in the address does not match this request: start again.\n" >&2
  exit 1
fi

# Exchange the code for the app credentials. The one-time code goes through
# curl's config on stdin rather than its arguments.
printf "\nRetrieving the app credentials...\n"
CREDENTIALS="$(printf 'url = "https://api.github.com/app-manifests/%s/conversions"\n' "$CODE" | curl -fsSL -K - \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28")"

APP_SLUG="$(jq -r '.slug // empty' <<< "$CREDENTIALS")"
if [ -z "$APP_SLUG" ]; then
  printf "\n${COLOR_RED}Failed to create GitHub App.${COLOR_OFF}\n" >&2
  jq -r '.message // .' <<< "$CREDENTIALS" >&2 || true
  exit 1
fi

OUTPUT_FILE="${OUTPUT_FILE:-github-app-$APP_SLUG.json}"
(umask 077 && printf '%s\n' "$CREDENTIALS" > "$OUTPUT_FILE")
chmod 600 "$OUTPUT_FILE"

printf "\n${COLOR_GREEN}GitHub App created successfully.${COLOR_OFF}\n"
jq '{id, slug, client_id, html_url}' <<< "$CREDENTIALS"
printf "Credentials (client secret, webhook secret, private key) saved to '%s'.\n" "$OUTPUT_FILE"

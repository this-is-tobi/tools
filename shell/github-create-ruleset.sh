#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

TEXT_HELPER="
This script configures branch protection rules for a GitHub repository using the REST API.

Following flags are available:

  -o    Owner (organization or user).

  -r    Repository name.

  -t    GitHub Personal Access Token.

  -b    Branch name (default: main).

  -a    Enforce for admins (default: true).

  -p    Require pull request reviews (default: true).

  -c    Required status checks contexts (comma-separated, default: none).

  -l    Require linear history (default: true).

  -f    Allow force pushes (default: false).

  -d    Allow deletions (default: false).

  -s    Require signed commits (default: true).

  -h    Print script help.


Example:

  ./configure-branch-rules.sh \\
    -o 'this-is-tobi' \\
    -r 'tools' \\
    -t 'ghp_xxx' \\
    -b 'main'
"

print_help() {
  printf "$TEXT_HELPER"
}

# Defaults
BRANCH="main"
ENFORCE_ADMINS=true
REQUIRE_REVIEWS=true
REQUIRED_CONTEXTS=""
REQUIRE_LINEAR=true
ALLOW_FORCE=false
ALLOW_DELETE=false
REQUIRE_SIGNATURES=true

# Parse options
while getopts "ho:r:t:b:a:p:c:l:f:d:s:" flag; do
  case "${flag}" in
    o)
      OWNER=${OPTARG};;
    r)
      REPO=${OPTARG};;
    t)
      TOKEN=${OPTARG};;
    b)
      BRANCH=${OPTARG};;
    a)
      ENFORCE_ADMINS=${OPTARG};;
    p)
      REQUIRE_REVIEWS=${OPTARG};;
    c)
      REQUIRED_CONTEXTS=${OPTARG};;
    l)
      REQUIRE_LINEAR=${OPTARG};;
    f)
      ALLOW_FORCE=${OPTARG};;
    d)
      ALLOW_DELETE=${OPTARG};;
    s)
      REQUIRE_SIGNATURES=${OPTARG};;
    h | *)
      print_help; 
      exit 0;;
  esac
done

if [ -z "$OWNER" ]; then
  printf "\n${red}Error.${no_color} Argument missing: owner (flag -o).\n"
  exit 1
elif [ -z "$REPO" ]; then
  printf "\n${red}Error.${no_color} Argument missing: repository (flag -r).\n"
  exit 1
elif [ -z "$TOKEN" ]; then
  printf "\n${red}Error.${no_color} Argument missing: token (flag -t).\n"
  exit 1
fi

API_URL="https://api.github.com/repos/$OWNER/$REPO/branches/$BRANCH/protection"

# Build required status checks
if [ -n "$REQUIRED_CONTEXTS" ]; then
  CONTEXTS_JSON=$(jq -n --arg contexts "$REQUIRED_CONTEXTS" '($contexts | split(","))')
else
  CONTEXTS_JSON="[]"
fi

# Build required pull request reviews
if [ "$REQUIRE_REVIEWS" = "true" ]; then
  REVIEWS_JSON='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true}'
else
  REVIEWS_JSON="null"
fi

PAYLOAD=$(jq -n \
  --argjson contexts "$CONTEXTS_JSON" \
  --argjson reviews "$REVIEWS_JSON" \
  --argjson admins "$ENFORCE_ADMINS" \
  --argjson linear "$REQUIRE_LINEAR" \
  --argjson force "$ALLOW_FORCE" \
  --argjson delete "$ALLOW_DELETE" \
  --argjson signatures "$REQUIRE_SIGNATURES" \
  '{
    required_status_checks: {strict: true, contexts: $contexts},
    enforce_admins: $admins,
    required_pull_request_reviews: $reviews,
    restrictions: null,
    required_linear_history: $linear,
    allow_force_pushes: $force,
    allow_deletions: $delete,
    required_signatures: $signatures
  }')

printf "Applying branch protection to $OWNER/$REPO branch '$BRANCH'...\n\n"

RESPONSE=$(curl -s -X PUT "$API_URL" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$PAYLOAD")

if echo "$RESPONSE" | jq -e '.url' > /dev/null; then
  echo "Branch protection applied successfully."
  echo "$RESPONSE" | jq
else
  echo "Failed to apply branch protection."
  exit 1
fi

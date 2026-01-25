#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
BRANCH="main"
ENFORCE_ADMINS=true
REQUIRE_REVIEWS=true
REQUIRED_CONTEXTS=""
REQUIRE_LINEAR=true
ALLOW_FORCE=false
ALLOW_DELETE=false
REQUIRE_SIGNATURES=true

TEXT_HELPER="
This script configures branch protection rules for a GitHub repository using the REST API.

Available flags:
  -o    Owner (organization or user).
  -r    Repository name.
  -t    GitHub Personal Access Token.
  -b    Branch name.
        Default: '$BRANCH'.
  -a    Enforce for admins.
        Default: '$ENFORCE_ADMIN'.
  -p    Require pull request reviews.
        Default: '$REQUIRE_REVIEWS'.
  -c    Required status checks contexts (comma-separated).
        Default: 'none'.
  -l    Require linear history.
        Default: '$REQUIRE_LINEAR'.
  -f    Allow force pushes.
        Default: '$ALLOW_FORCE'.
  -d    Allow deletions.
        Default: '$ALLOW_DELETE'.
  -s    Require signed commits.
        Default: '$REQUIRE_SIGNATURES'.
  -h    Print script help.

Example:
  ./configure-branch-rules.sh \\
    -o 'this-is-tobi' \\
    -r 'tools' \\
    -t 'ghp_xxx' \\
    -b 'main'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

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

# Settings
printf "
Settings:
  > OWNER: ${OWNER}
  > REPO: ${REPO}
  > BRANCH: ${BRANCH}
  > ENFORCE_ADMINS: ${ENFORCE_ADMINS}
  > REQUIRE_REVIEWS: ${REQUIRE_REVIEWS}
  > REQUIRED_CONTEXTS: ${REQUIRED_CONTEXTS:-none}
  > REQUIRE_LINEAR: ${REQUIRE_LINEAR}
  > ALLOW_FORCE: ${ALLOW_FORCE}
  > ALLOW_DELETE: ${ALLOW_DELETE}
  > REQUIRE_SIGNATURES: ${REQUIRE_SIGNATURES}
"

# Options validation
if [ -z "$OWNER" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: owner (flag -o).\n"
  exit 1
elif [ -z "$REPO" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: repository (flag -r).\n"
  exit 1
elif [ -z "$TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: token (flag -t).\n"
  exit 1
fi

# Init
API_URL="https://api.github.com/repos/$OWNER/$REPO/branches/$BRANCH/protection"

# Build required status checks
if [ -n "$REQUIRED_CONTEXTS" ]; then
  CONTEXTS_JSON=$(jq -n --arg contexts "$REQUIRED_CONTEXTS" '($contexts | split(","))')
else
  CONTEXTS_JSON="[]"
fi

# Build required pull request reviews
if [ "$REQUIRE_REVIEWS" = "true" ]; then
  REVIEWS_JSON='{"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":false}'
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

printf "Applying branch protection to '$OWNER/$REPO' on branch '$BRANCH'...\n"

RESPONSE=$(curl -s -X PUT "$API_URL" \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "$PAYLOAD")

if echo "$RESPONSE" | jq -e '.url' > /dev/null; then
  printf "Branch protection applied successfully.\n"
  echo "$RESPONSE" | jq
else
  printf "Failed to apply branch protection.\n"
  echo "$RESPONSE" | jq
  exit 1
fi

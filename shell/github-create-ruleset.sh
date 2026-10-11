#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
OWNER=""
REPO=""
TOKEN=""
MODE="branch-protection"
BRANCH="main"
BRANCH_SET="false"
RULESET_NAME="Default branch"
ENFORCE_ADMINS=true
REQUIRE_REVIEWS=true
REQUIRED_APPROVALS=1
REQUIRED_CONTEXTS=""
REQUIRE_LINEAR=true
ALLOW_FORCE=false
ALLOW_DELETE=false
REQUIRE_SIGNATURES=true

TEXT_HELPER="
This script protects a branch of a GitHub repository using the REST API.

Two modes are available:
  - 'branch-protection' (default) applies classic branch protection to the branch.
  - 'ruleset' creates, or updates in place, a repository ruleset named after -n
    that targets the default branch (or the branch given with -b). It blocks
    deletions (-d) and force pushes (-f) and can require linear history (-l),
    signed commits (-s), status checks (-c) and pull request reviews (-p).
    Repository admins can bypass it when -a is 'false'.

Authentication:
  The token is read from GH_TOKEN, then GITHUB_TOKEN, then 'gh auth token'.
  It needs admin access to the repository. Passing it with -t still works, but
  exposes it in the process list and the shell history.

Available flags:
  -o    Owner (organization or user).
  -r    Repository name.
  -t    GitHub token (prefer GH_TOKEN / GITHUB_TOKEN).
  -m    Mode: 'branch-protection' or 'ruleset'.
        Default: '$MODE'.
  -n    Ruleset name (ruleset mode).
        Default: '$RULESET_NAME'.
  -b    Branch name.
        Default: '$BRANCH' (branch-protection mode), the default branch (ruleset mode).
  -a    Enforce for admins. In ruleset mode, 'false' lets repository admins bypass the ruleset.
        Default: '$ENFORCE_ADMINS'.
  -p    Require pull requests, stale reviews being dismissed on push.
        Default: '$REQUIRE_REVIEWS'.
  -A    Number of approving reviews required when -p is 'true' (0 only requires a pull request).
        Default: '$REQUIRED_APPROVALS'.
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
  ./github-create-ruleset.sh \\
    -o 'this-is-tobi' \\
    -r 'tools' \\
    -b 'main'

  ./github-create-ruleset.sh \\
    -o 'this-is-tobi' \\
    -r 'tools' \\
    -m 'ruleset' \\
    -c 'ci / lint,ci / test' \\
    -a 'false'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# A token given with -t is visible in the process list and the shell history:
# the environment and the gh CLI keep it out of both.
resolve_token() {
  if [ -z "$TOKEN" ]; then
    TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
  fi
  if [ -z "$TOKEN" ] && command -v gh > /dev/null 2>&1; then
    TOKEN="$(gh auth token 2> /dev/null || true)"
  fi
}

# Prints the Authorization header; curl reads it through a file descriptor so
# the token never appears in its arguments.
auth_header() {
  printf 'Authorization: Bearer %s\n' "$TOKEN"
}

# Perform an API call (JSON body on stdin when given) and print the response body.
# Fails (after printing the API message on stderr) unless the HTTP status is 2xx.
github_api() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local http_response
  local http_body
  local http_status

  if [ -n "$data" ]; then
    http_response=$(printf '%s' "$data" | curl -sS -w "\n%{http_code}" -X "$method" "$url" \
      -H @<(auth_header) \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" \
      --data-binary @-) || return 1
  else
    http_response=$(curl -sS -w "\n%{http_code}" -X "$method" "$url" \
      -H @<(auth_header) \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28") || return 1
  fi

  http_status=$(printf '%s\n' "$http_response" | tail -n1)
  http_body=$(printf '%s\n' "$http_response" | sed '$d')

  case "$http_status" in
    2??) ;;
    *)
      printf "${COLOR_RED}API call failed (HTTP %s):${COLOR_OFF} %s %s\n" "$http_status" "$method" "$url" >&2
      printf '%s\n' "$http_body" | jq -r '.message // .' >&2 2> /dev/null || printf '%s\n' "$http_body" >&2
      return 1;;
  esac

  printf '%s\n' "$http_body"
}

# Parse options
while getopts "ho:r:t:m:n:b:a:p:A:c:l:f:d:s:" flag; do
  case "${flag}" in
    o)
      OWNER=${OPTARG};;
    r)
      REPO=${OPTARG};;
    t)
      TOKEN=${OPTARG}
      printf "${COLOR_YELLOW}Warning.${COLOR_OFF} Token passed with -t: it is visible in the process list and the shell history, prefer GH_TOKEN.\n" >&2;;
    m)
      MODE=${OPTARG};;
    n)
      RULESET_NAME=${OPTARG};;
    b)
      BRANCH=${OPTARG}
      BRANCH_SET="true";;
    a)
      ENFORCE_ADMINS=${OPTARG};;
    p)
      REQUIRE_REVIEWS=${OPTARG};;
    A)
      REQUIRED_APPROVALS=${OPTARG};;
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

if [ "$MODE" = "ruleset" ] && [ "$BRANCH_SET" = "false" ]; then
  BRANCH_DISPLAY="default branch"
else
  BRANCH_DISPLAY="$BRANCH"
fi

# Settings
printf "
Settings:
  > OWNER: ${OWNER}
  > REPO: ${REPO}
  > MODE: ${MODE}
  > BRANCH: ${BRANCH_DISPLAY}
  > ENFORCE_ADMINS: ${ENFORCE_ADMINS}
  > REQUIRE_REVIEWS: ${REQUIRE_REVIEWS}
  > REQUIRED_APPROVALS: ${REQUIRED_APPROVALS}
  > REQUIRED_CONTEXTS: ${REQUIRED_CONTEXTS:-none}
  > REQUIRE_LINEAR: ${REQUIRE_LINEAR}
  > ALLOW_FORCE: ${ALLOW_FORCE}
  > ALLOW_DELETE: ${ALLOW_DELETE}
  > REQUIRE_SIGNATURES: ${REQUIRE_SIGNATURES}
"

# Options validation
resolve_token

if [ -z "$OWNER" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: owner (flag -o).\n" >&2
  exit 1
elif [ -z "$REPO" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Argument missing: repository (flag -r).\n" >&2
  exit 1
elif [ -z "$TOKEN" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} No token found: set GH_TOKEN or GITHUB_TOKEN, log in with 'gh auth login', or use flag -t.\n" >&2
  exit 1
elif [ "$MODE" != "branch-protection" ] && [ "$MODE" != "ruleset" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid mode (flag -m): must be 'branch-protection' or 'ruleset'.\n" >&2
  exit 1
elif ! printf '%s' "$REQUIRED_APPROVALS" | grep -Eq '^[0-9]$|^10$'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid number of approvals (flag -A): must be between 0 and 10.\n" >&2
  exit 1
fi

for BOOLEAN_SETTING in ENFORCE_ADMINS REQUIRE_REVIEWS REQUIRE_LINEAR ALLOW_FORCE ALLOW_DELETE REQUIRE_SIGNATURES; do
  if [ "${!BOOLEAN_SETTING}" != "true" ] && [ "${!BOOLEAN_SETTING}" != "false" ]; then
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for %s: '%s' (expected 'true' or 'false').\n" "$BOOLEAN_SETTING" "${!BOOLEAN_SETTING}" >&2
    exit 1
  fi
done

# Init
REPO_URL="https://api.github.com/repos/$OWNER/$REPO"

# Build required status checks
if [ -n "$REQUIRED_CONTEXTS" ]; then
  CONTEXTS_JSON=$(jq -n --arg contexts "$REQUIRED_CONTEXTS" '$contexts | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))')
else
  CONTEXTS_JSON="[]"
fi

if [ "$MODE" = "branch-protection" ]; then
  # Build required pull request reviews
  if [ "$REQUIRE_REVIEWS" = "true" ]; then
    REVIEWS_JSON=$(jq -n --argjson approvals "$REQUIRED_APPROVALS" \
      '{required_approving_review_count: $approvals, dismiss_stale_reviews: true, require_code_owner_reviews: false}')
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
    '{
      required_status_checks: (if ($contexts | length) > 0 then {strict: true, contexts: $contexts} else null end),
      enforce_admins: $admins,
      required_pull_request_reviews: $reviews,
      restrictions: null,
      required_linear_history: $linear,
      allow_force_pushes: $force,
      allow_deletions: $delete
    }')

  printf "Applying branch protection to '%s/%s' on branch '%s'...\n" "$OWNER" "$REPO" "$BRANCH"

  if ! RESPONSE=$(github_api PUT "$REPO_URL/branches/$BRANCH/protection" "$PAYLOAD"); then
    printf "${COLOR_RED}Failed to apply branch protection.${COLOR_OFF}\n" >&2
    exit 1
  fi

  # Signed commits have their own endpoint: the protection payload has no such field.
  SIGNATURES_URL="$REPO_URL/branches/$BRANCH/protection/required_signatures"
  if ! SIGNATURES=$(github_api GET "$SIGNATURES_URL"); then
    printf "${COLOR_RED}Failed to read the signed commits setting.${COLOR_OFF}\n" >&2
    exit 1
  fi
  SIGNATURES_ENABLED="$(printf '%s\n' "$SIGNATURES" | jq -r '.enabled')"
  if [ "$REQUIRE_SIGNATURES" = "true" ] && [ "$SIGNATURES_ENABLED" != "true" ]; then
    github_api POST "$SIGNATURES_URL" > /dev/null || { printf "${COLOR_RED}Failed to require signed commits.${COLOR_OFF}\n" >&2; exit 1; }
  elif [ "$REQUIRE_SIGNATURES" = "false" ] && [ "$SIGNATURES_ENABLED" = "true" ]; then
    github_api DELETE "$SIGNATURES_URL" > /dev/null || { printf "${COLOR_RED}Failed to stop requiring signed commits.${COLOR_OFF}\n" >&2; exit 1; }
  fi

  printf "${COLOR_GREEN}Branch protection applied successfully (signed commits required: %s).${COLOR_OFF}\n" "$REQUIRE_SIGNATURES"
  printf '%s\n' "$RESPONSE" | jq
  exit 0
fi

# Ruleset mode
if [ "$BRANCH_SET" = "true" ]; then
  REF_PATTERN="refs/heads/$BRANCH"
else
  REF_PATTERN="~DEFAULT_BRANCH"
fi

# Repository role id 5 is the built-in admin role.
PAYLOAD=$(jq -n \
  --arg name "$RULESET_NAME" \
  --arg ref "$REF_PATTERN" \
  --argjson contexts "$CONTEXTS_JSON" \
  --argjson admins "$ENFORCE_ADMINS" \
  --argjson reviews "$REQUIRE_REVIEWS" \
  --argjson approvals "$REQUIRED_APPROVALS" \
  --argjson linear "$REQUIRE_LINEAR" \
  --argjson force "$ALLOW_FORCE" \
  --argjson delete "$ALLOW_DELETE" \
  --argjson signatures "$REQUIRE_SIGNATURES" \
  '{
    name: $name,
    target: "branch",
    enforcement: "active",
    conditions: {ref_name: {include: [$ref], exclude: []}},
    bypass_actors: (if $admins then [] else [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}] end),
    rules: (
      (if $delete then [] else [{type: "deletion"}] end)
      + (if $force then [] else [{type: "non_fast_forward"}] end)
      + (if $linear then [{type: "required_linear_history"}] else [] end)
      + (if $signatures then [{type: "required_signatures"}] else [] end)
      + (if ($contexts | length) > 0 then [{
          type: "required_status_checks",
          parameters: {
            strict_required_status_checks_policy: true,
            required_status_checks: ($contexts | map({context: .}))
          }
        }] else [] end)
      + (if $reviews then [{
          type: "pull_request",
          parameters: {
            required_approving_review_count: $approvals,
            dismiss_stale_reviews_on_push: true,
            require_code_owner_review: false,
            require_last_push_approval: false,
            required_review_thread_resolution: false
          }
        }] else [] end)
    )
  }')

# Update the ruleset in place when one with the same name exists, so running the
# script twice never creates a duplicate.
if ! EXISTING_RULESETS=$(github_api GET "$REPO_URL/rulesets?includes_parents=false&per_page=100"); then
  printf "${COLOR_RED}Failed to list the repository rulesets.${COLOR_OFF}\n" >&2
  exit 1
fi
EXISTING_ID=$(printf '%s\n' "$EXISTING_RULESETS" | jq -r --arg name "$RULESET_NAME" '[.[] | select(.name == $name and .target == "branch")][0].id // empty')

if [ -n "$EXISTING_ID" ]; then
  printf "Updating ruleset '%s' (id=%s) on '%s/%s'...\n" "$RULESET_NAME" "$EXISTING_ID" "$OWNER" "$REPO"
  RESPONSE=$(github_api PUT "$REPO_URL/rulesets/$EXISTING_ID" "$PAYLOAD") || { printf "${COLOR_RED}Failed to update the ruleset.${COLOR_OFF}\n" >&2; exit 1; }
else
  printf "Creating ruleset '%s' on '%s/%s'...\n" "$RULESET_NAME" "$OWNER" "$REPO"
  RESPONSE=$(github_api POST "$REPO_URL/rulesets" "$PAYLOAD") || { printf "${COLOR_RED}Failed to create the ruleset.${COLOR_OFF}\n" >&2; exit 1; }
fi

printf "${COLOR_GREEN}Ruleset applied successfully.${COLOR_OFF}\n"
printf '%s\n' "$RESPONSE" | jq

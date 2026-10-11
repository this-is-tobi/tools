#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Defaults
OWNER=""
REPO=""
TOKEN=""

# Repository settings
DELETE_BRANCH_ON_MERGE=true
ALLOW_SQUASH_MERGE=true
ALLOW_MERGE_COMMIT=false
ALLOW_REBASE_MERGE=true
ALLOW_AUTO_MERGE=false
ALLOW_UPDATE_BRANCH=true
HAS_WIKI=false
HAS_PROJECTS=false
HAS_ISSUES=true
WEB_COMMIT_SIGNOFF_REQUIRED=true

# Security features
ENABLE_VULNERABILITY_ALERTS=true
ENABLE_AUTOMATED_SECURITY_FIXES=false
ENABLE_PRIVATE_VULNERABILITY_REPORTING=true
ENABLE_SECRET_SCANNING=true
ENABLE_SECRET_SCANNING_PUSH_PROTECTION=true

# GitHub Actions
ACTIONS_ENABLED=true
ACTIONS_ALLOWED="all"
ACTIONS_SHA_PINNING_REQUIRED=true
ACTIONS_GITHUB_OWNED=true
ACTIONS_VERIFIED=false
ACTIONS_PATTERNS=""
WORKFLOW_DEFAULT_PERMISSION="read"
WORKFLOW_CAN_APPROVE_PR=false

# Immutable releases
ENABLE_IMMUTABLE_RELEASES=true
IMMUTABLE_TAGS_PATTERN="v*"

TEXT_HELPER="
This script configures GitHub repository settings and security best practices using the REST API.
It complements github-create-ruleset.sh (branch protection) and github-create-app.sh (app creation).

Every setting is applied with an idempotent call, so the script can be run
again at any time. A failed call does not stop the others: they are all
reported at the end and the script exits non-zero.

Configured settings:
  - Repository merge strategy and general settings
  - Vulnerability alerts and automated security fixes (Dependabot)
  - Private vulnerability reporting
  - Secret scanning and push protection
  - GitHub Actions permissions and default workflow permissions
  - Immutable releases via tag rulesets

Authentication:
  The token is read from GH_TOKEN, then GITHUB_TOKEN, then 'gh auth token'.
  It needs admin access to the repository. Passing it with -t still works, but
  exposes it in the process list and the shell history.

Available flags:
  -o    Owner (organization or user). [required]
  -r    Repository name. [required]
  -t    GitHub token (prefer GH_TOKEN / GITHUB_TOKEN).

  Repository settings:
  -D    Delete branch on merge.
        Default: '$DELETE_BRANCH_ON_MERGE'.
  -S    Allow squash merge.
        Default: '$ALLOW_SQUASH_MERGE'.
  -M    Allow merge commit.
        Default: '$ALLOW_MERGE_COMMIT'.
  -R    Allow rebase merge.
        Default: '$ALLOW_REBASE_MERGE'.
  -A    Allow auto merge.
        Default: '$ALLOW_AUTO_MERGE'.
  -U    Allow contributors to update branches.
        Default: '$ALLOW_UPDATE_BRANCH'.
  -w    Enable wiki.
        Default: '$HAS_WIKI'.
  -j    Enable projects.
        Default: '$HAS_PROJECTS'.
  -I    Enable issues.
        Default: '$HAS_ISSUES'.
  -G    Require web commit sign-off.
        Default: '$WEB_COMMIT_SIGNOFF_REQUIRED'.

  Security features:
  -v    Enable vulnerability alerts (Dependabot).
        Default: '$ENABLE_VULNERABILITY_ALERTS'.
  -x    Enable automated security fixes (Dependabot pull requests).
        Leave it off when Renovate already opens vulnerability fixes.
        Default: '$ENABLE_AUTOMATED_SECURITY_FIXES'.
  -V    Enable private vulnerability reporting.
        Default: '$ENABLE_PRIVATE_VULNERABILITY_REPORTING'.
  -s    Enable secret scanning.
        Default: '$ENABLE_SECRET_SCANNING'.
  -P    Enable secret scanning push protection.
        Default: '$ENABLE_SECRET_SCANNING_PUSH_PROTECTION'.

  GitHub Actions:
  -a    Actions allowed: 'all', 'local_only', 'selected'.
        Default: '$ACTIONS_ALLOWED'.
  -H    Require actions and reusable workflows to be pinned to a full-length commit SHA.
        Default: '$ACTIONS_SHA_PINNING_REQUIRED'.
  -g    When actions_allowed=selected, allow GitHub-owned actions.
        Default: '$ACTIONS_GITHUB_OWNED'.
  -e    When actions_allowed=selected, allow verified creator actions.
        Default: '$ACTIONS_VERIFIED'.
  -L    When actions_allowed=selected, comma-separated patterns of other allowed actions
        and reusable workflows (e.g. 'docker/*,this-is-tobi/github-workflows/*').
        Default: none.
  -W    Default workflow token permissions: 'read' or 'write'.
        Default: '$WORKFLOW_DEFAULT_PERMISSION'.
  -p    Allow workflows to approve pull requests.
        Default: '$WORKFLOW_CAN_APPROVE_PR'.

  Immutable releases:
  -i    Enable immutable releases (tag protection ruleset).
        Default: '$ENABLE_IMMUTABLE_RELEASES'.
  -T    Glob pattern for immutable release tags (e.g. 'v*', '*').
        Default: '$IMMUTABLE_TAGS_PATTERN'.

  -h    Print script help.

Example:
  ./github-configure-repo.sh \\
    -o 'this-is-tobi' \\
    -r 'tools' \\
    -T '*'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

log_step() {
  printf "\n${COLOR_BLUE}==> %s${COLOR_OFF}\n" "$1"
}

log_success() {
  printf "${COLOR_GREEN}✔ %s${COLOR_OFF}\n" "$1"
}

log_warn() {
  printf "${COLOR_YELLOW}⚠ %s${COLOR_OFF}\n" "$1" >&2
}

log_error() {
  printf "${COLOR_RED}✖ %s${COLOR_OFF}\n" "$1" >&2
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

# Perform an API call and print the response body.
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
      --data-binary @-) || { log_error "API call failed: $method $url"; return 1; }
  else
    http_response=$(curl -sS -w "\n%{http_code}" -X "$method" "$url" \
      -H @<(auth_header) \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28") || { log_error "API call failed: $method $url"; return 1; }
  fi

  http_status=$(printf '%s\n' "$http_response" | tail -n1)
  http_body=$(printf '%s\n' "$http_response" | sed '$d')

  case "$http_status" in
    2??) ;;
    *)
      log_error "API call failed (HTTP $http_status): $method $url"
      printf '%s\n' "$http_body" | jq -r '.message // .' >&2 2> /dev/null || printf '%s\n' "$http_body" >&2
      return 1;;
  esac

  printf '%s\n' "$http_body"
}

# Runs one API call, prints the outcome and counts failures instead of stopping,
# so every setting gets a chance to be applied.
FAILURES=0
apply() {
  local message="$1"
  shift
  if github_api "$@" > /dev/null; then
    log_success "$message"
  else
    FAILURES=$((FAILURES + 1))
  fi
}

# Parse options
while getopts "ho:r:t:D:S:M:R:A:U:w:j:I:G:v:x:V:s:P:a:H:g:e:L:W:p:i:T:" flag; do
  case "${flag}" in
    o) OWNER=${OPTARG};;
    r) REPO=${OPTARG};;
    t) TOKEN=${OPTARG}; log_warn "Token passed with -t: it is visible in the process list and the shell history, prefer GH_TOKEN.";;
    D) DELETE_BRANCH_ON_MERGE=${OPTARG};;
    S) ALLOW_SQUASH_MERGE=${OPTARG};;
    M) ALLOW_MERGE_COMMIT=${OPTARG};;
    R) ALLOW_REBASE_MERGE=${OPTARG};;
    A) ALLOW_AUTO_MERGE=${OPTARG};;
    U) ALLOW_UPDATE_BRANCH=${OPTARG};;
    w) HAS_WIKI=${OPTARG};;
    j) HAS_PROJECTS=${OPTARG};;
    I) HAS_ISSUES=${OPTARG};;
    G) WEB_COMMIT_SIGNOFF_REQUIRED=${OPTARG};;
    v) ENABLE_VULNERABILITY_ALERTS=${OPTARG};;
    x) ENABLE_AUTOMATED_SECURITY_FIXES=${OPTARG};;
    V) ENABLE_PRIVATE_VULNERABILITY_REPORTING=${OPTARG};;
    s) ENABLE_SECRET_SCANNING=${OPTARG};;
    P) ENABLE_SECRET_SCANNING_PUSH_PROTECTION=${OPTARG};;
    a) ACTIONS_ALLOWED=${OPTARG};;
    H) ACTIONS_SHA_PINNING_REQUIRED=${OPTARG};;
    g) ACTIONS_GITHUB_OWNED=${OPTARG};;
    e) ACTIONS_VERIFIED=${OPTARG};;
    L) ACTIONS_PATTERNS=${OPTARG};;
    W) WORKFLOW_DEFAULT_PERMISSION=${OPTARG};;
    p) WORKFLOW_CAN_APPROVE_PR=${OPTARG};;
    i) ENABLE_IMMUTABLE_RELEASES=${OPTARG};;
    T) IMMUTABLE_TAGS_PATTERN=${OPTARG};;
    h) print_help; exit 0;;
    *) print_help >&2; exit 1;;
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
  Repository:
  > OWNER: ${OWNER}
  > REPO: ${REPO}
  > DELETE_BRANCH_ON_MERGE: ${DELETE_BRANCH_ON_MERGE}
  > ALLOW_SQUASH_MERGE: ${ALLOW_SQUASH_MERGE}
  > ALLOW_MERGE_COMMIT: ${ALLOW_MERGE_COMMIT}
  > ALLOW_REBASE_MERGE: ${ALLOW_REBASE_MERGE}
  > ALLOW_AUTO_MERGE: ${ALLOW_AUTO_MERGE}
  > ALLOW_UPDATE_BRANCH: ${ALLOW_UPDATE_BRANCH}
  > HAS_WIKI: ${HAS_WIKI}
  > HAS_PROJECTS: ${HAS_PROJECTS}
  > HAS_ISSUES: ${HAS_ISSUES}
  > WEB_COMMIT_SIGNOFF_REQUIRED: ${WEB_COMMIT_SIGNOFF_REQUIRED}

  Security:
  > ENABLE_VULNERABILITY_ALERTS: ${ENABLE_VULNERABILITY_ALERTS}
  > ENABLE_AUTOMATED_SECURITY_FIXES: ${ENABLE_AUTOMATED_SECURITY_FIXES}
  > ENABLE_PRIVATE_VULNERABILITY_REPORTING: ${ENABLE_PRIVATE_VULNERABILITY_REPORTING}
  > ENABLE_SECRET_SCANNING: ${ENABLE_SECRET_SCANNING}
  > ENABLE_SECRET_SCANNING_PUSH_PROTECTION: ${ENABLE_SECRET_SCANNING_PUSH_PROTECTION}

  GitHub Actions:
  > ACTIONS_ALLOWED: ${ACTIONS_ALLOWED}
  > ACTIONS_SHA_PINNING_REQUIRED: ${ACTIONS_SHA_PINNING_REQUIRED}
  > ACTIONS_GITHUB_OWNED: ${ACTIONS_GITHUB_OWNED}
  > ACTIONS_VERIFIED: ${ACTIONS_VERIFIED}
  > ACTIONS_PATTERNS: ${ACTIONS_PATTERNS:-none}
  > WORKFLOW_DEFAULT_PERMISSION: ${WORKFLOW_DEFAULT_PERMISSION}
  > WORKFLOW_CAN_APPROVE_PR: ${WORKFLOW_CAN_APPROVE_PR}

  Immutable releases:
  > ENABLE_IMMUTABLE_RELEASES: ${ENABLE_IMMUTABLE_RELEASES}
  > IMMUTABLE_TAGS_PATTERN: ${IMMUTABLE_TAGS_PATTERN}
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
fi

for BOOLEAN_SETTING in DELETE_BRANCH_ON_MERGE ALLOW_SQUASH_MERGE ALLOW_MERGE_COMMIT ALLOW_REBASE_MERGE \
  ALLOW_AUTO_MERGE ALLOW_UPDATE_BRANCH HAS_WIKI HAS_PROJECTS HAS_ISSUES WEB_COMMIT_SIGNOFF_REQUIRED \
  ENABLE_VULNERABILITY_ALERTS ENABLE_AUTOMATED_SECURITY_FIXES ENABLE_PRIVATE_VULNERABILITY_REPORTING \
  ENABLE_SECRET_SCANNING ENABLE_SECRET_SCANNING_PUSH_PROTECTION ACTIONS_SHA_PINNING_REQUIRED \
  ACTIONS_GITHUB_OWNED ACTIONS_VERIFIED WORKFLOW_CAN_APPROVE_PR ENABLE_IMMUTABLE_RELEASES; do
  if [ "${!BOOLEAN_SETTING}" != "true" ] && [ "${!BOOLEAN_SETTING}" != "false" ]; then
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for %s: '%s' (expected 'true' or 'false').\n" "$BOOLEAN_SETTING" "${!BOOLEAN_SETTING}" >&2
    exit 1
  fi
done

if [[ "$ACTIONS_ALLOWED" != "all" && "$ACTIONS_ALLOWED" != "local_only" && "$ACTIONS_ALLOWED" != "selected" ]]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for -a: must be 'all', 'local_only', or 'selected'.\n" >&2
  exit 1
fi

if [[ "$WORKFLOW_DEFAULT_PERMISSION" != "read" && "$WORKFLOW_DEFAULT_PERMISSION" != "write" ]]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for -W: must be 'read' or 'write'.\n" >&2
  exit 1
fi

BASE_URL="https://api.github.com/repos/$OWNER/$REPO"

# ─────────────────────────────────────────────
# 1. Repository general settings
# ─────────────────────────────────────────────
log_step "Configuring repository general settings..."

REPO_PAYLOAD=$(jq -n \
  --argjson delete_branch "$DELETE_BRANCH_ON_MERGE" \
  --argjson squash "$ALLOW_SQUASH_MERGE" \
  --argjson merge_commit "$ALLOW_MERGE_COMMIT" \
  --argjson rebase "$ALLOW_REBASE_MERGE" \
  --argjson auto_merge "$ALLOW_AUTO_MERGE" \
  --argjson update_branch "$ALLOW_UPDATE_BRANCH" \
  --argjson wiki "$HAS_WIKI" \
  --argjson projects "$HAS_PROJECTS" \
  --argjson issues "$HAS_ISSUES" \
  --argjson signoff "$WEB_COMMIT_SIGNOFF_REQUIRED" \
  '{
    delete_branch_on_merge: $delete_branch,
    allow_squash_merge: $squash,
    allow_merge_commit: $merge_commit,
    allow_rebase_merge: $rebase,
    allow_auto_merge: $auto_merge,
    allow_update_branch: $update_branch,
    has_wiki: $wiki,
    has_projects: $projects,
    has_issues: $issues,
    web_commit_signoff_required: $signoff
  }')

apply "Repository general settings applied." PATCH "$BASE_URL" "$REPO_PAYLOAD"

# ─────────────────────────────────────────────
# 2. Secret scanning
# ─────────────────────────────────────────────
# Sent apart from the general settings: on repositories where these features are
# unavailable (private repositories without GitHub Advanced Security) the call
# fails, and it must not take the general settings down with it.
log_step "Configuring secret scanning..."

SECRET_SCANNING_STATUS=$([ "$ENABLE_SECRET_SCANNING" = "true" ] && echo "enabled" || echo "disabled")
PUSH_PROTECTION_STATUS=$([ "$ENABLE_SECRET_SCANNING_PUSH_PROTECTION" = "true" ] && echo "enabled" || echo "disabled")

SECURITY_PAYLOAD=$(jq -n \
  --arg ss_status "$SECRET_SCANNING_STATUS" \
  --arg pp_status "$PUSH_PROTECTION_STATUS" \
  '{
    security_and_analysis: {
      secret_scanning: {status: $ss_status},
      secret_scanning_push_protection: {status: $pp_status}
    }
  }')

apply "Secret scanning $SECRET_SCANNING_STATUS, push protection $PUSH_PROTECTION_STATUS." PATCH "$BASE_URL" "$SECURITY_PAYLOAD"

# ─────────────────────────────────────────────
# 3. Vulnerability alerts (Dependabot)
# ─────────────────────────────────────────────
log_step "Configuring vulnerability alerts..."

if [ "$ENABLE_VULNERABILITY_ALERTS" = "true" ]; then
  apply "Vulnerability alerts enabled." PUT "$BASE_URL/vulnerability-alerts"
else
  apply "Vulnerability alerts disabled." DELETE "$BASE_URL/vulnerability-alerts"
fi

# ─────────────────────────────────────────────
# 4. Automated security fixes (Dependabot PRs)
# ─────────────────────────────────────────────
log_step "Configuring automated security fixes..."

if [ "$ENABLE_AUTOMATED_SECURITY_FIXES" = "true" ]; then
  apply "Automated security fixes enabled." PUT "$BASE_URL/automated-security-fixes"
else
  apply "Automated security fixes disabled." DELETE "$BASE_URL/automated-security-fixes"
fi

# ─────────────────────────────────────────────
# 5. Private vulnerability reporting
# ─────────────────────────────────────────────
log_step "Configuring private vulnerability reporting..."

if [ "$ENABLE_PRIVATE_VULNERABILITY_REPORTING" = "true" ]; then
  apply "Private vulnerability reporting enabled." PUT "$BASE_URL/private-vulnerability-reporting"
else
  apply "Private vulnerability reporting disabled." DELETE "$BASE_URL/private-vulnerability-reporting"
fi

# ─────────────────────────────────────────────
# 6. GitHub Actions permissions
# ─────────────────────────────────────────────
log_step "Configuring GitHub Actions permissions..."

ACTIONS_PAYLOAD=$(jq -n \
  --argjson enabled "$ACTIONS_ENABLED" \
  --arg allowed "$ACTIONS_ALLOWED" \
  --argjson sha_pinning "$ACTIONS_SHA_PINNING_REQUIRED" \
  '{enabled: $enabled, allowed_actions: $allowed, sha_pinning_required: $sha_pinning}')

apply "Actions permissions set (allowed: $ACTIONS_ALLOWED, sha_pinning_required: $ACTIONS_SHA_PINNING_REQUIRED)." \
  PUT "$BASE_URL/actions/permissions" "$ACTIONS_PAYLOAD"

# Configure selected actions allowlist when mode is 'selected'
if [ "$ACTIONS_ALLOWED" = "selected" ]; then
  SELECTED_PAYLOAD=$(jq -n \
    --argjson github_owned "$ACTIONS_GITHUB_OWNED" \
    --argjson verified "$ACTIONS_VERIFIED" \
    --arg patterns "$ACTIONS_PATTERNS" \
    '{
      github_owned_allowed: $github_owned,
      verified_allowed: $verified,
      patterns_allowed: ($patterns | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))
    }')

  apply "Selected actions configured (github_owned=$ACTIONS_GITHUB_OWNED, verified=$ACTIONS_VERIFIED, patterns=${ACTIONS_PATTERNS:-none})." \
    PUT "$BASE_URL/actions/permissions/selected-actions" "$SELECTED_PAYLOAD"
fi

# ─────────────────────────────────────────────
# 7. Default workflow permissions (GITHUB_TOKEN)
# ─────────────────────────────────────────────
log_step "Configuring default workflow permissions..."

WORKFLOW_PAYLOAD=$(jq -n \
  --arg perm "$WORKFLOW_DEFAULT_PERMISSION" \
  --argjson can_approve "$WORKFLOW_CAN_APPROVE_PR" \
  '{default_workflow_permissions: $perm, can_approve_pull_request_reviews: $can_approve}')

apply "Default workflow permissions set (${WORKFLOW_DEFAULT_PERMISSION}, can_approve_pr=${WORKFLOW_CAN_APPROVE_PR})." \
  PUT "$BASE_URL/actions/permissions/workflow" "$WORKFLOW_PAYLOAD"

# ─────────────────────────────────────────────
# 8. Immutable releases (tag ruleset)
# ─────────────────────────────────────────────
log_step "Configuring immutable releases..."

if [ "$ENABLE_IMMUTABLE_RELEASES" = "true" ]; then
  TAG_INCLUDE_PATTERN="refs/tags/${IMMUTABLE_TAGS_PATTERN}"

  RULESET_PAYLOAD=$(jq -n \
    --arg pattern "$TAG_INCLUDE_PATTERN" \
    '{
      name: "Immutable releases",
      target: "tag",
      enforcement: "active",
      conditions: {
        ref_name: {
          include: [$pattern],
          exclude: []
        }
      },
      rules: [
        {type: "deletion"},
        {type: "non_fast_forward"},
        {type: "update"}
      ]
    }')

  # Update the ruleset in place when it already exists, so running the script twice
  # never creates a duplicate. A failed lookup skips the step rather than guessing.
  if EXISTING_RULESETS=$(github_api GET "$BASE_URL/rulesets?includes_parents=false&per_page=100"); then
    EXISTING_ID=$(printf '%s\n' "$EXISTING_RULESETS" | jq -r '[.[] | select(.name == "Immutable releases" and .target == "tag")][0].id // empty')

    if [ -n "$EXISTING_ID" ]; then
      apply "Immutable releases ruleset updated (id=$EXISTING_ID, pattern=$TAG_INCLUDE_PATTERN)." \
        PUT "$BASE_URL/rulesets/$EXISTING_ID" "$RULESET_PAYLOAD"
    else
      apply "Immutable releases ruleset created (pattern=$TAG_INCLUDE_PATTERN)." \
        POST "$BASE_URL/rulesets" "$RULESET_PAYLOAD"
    fi
  else
    FAILURES=$((FAILURES + 1))
  fi
else
  log_warn "Immutable releases disabled — skipping tag ruleset."
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
if [ "$FAILURES" -gt 0 ]; then
  printf "\n${COLOR_RED}Repository '%s/%s' configured with %s failed step(s), see the errors above.${COLOR_OFF}\n" "$OWNER" "$REPO" "$FAILURES" >&2
  exit 1
fi

printf "\n${COLOR_GREEN}Repository '%s/%s' configured successfully.${COLOR_OFF}\n" "$OWNER" "$REPO"

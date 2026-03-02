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
ENABLE_AUTOMATED_SECURITY_FIXES=true
ENABLE_PRIVATE_VULNERABILITY_REPORTING=true
ENABLE_SECRET_SCANNING=true
ENABLE_SECRET_SCANNING_PUSH_PROTECTION=true

# GitHub Actions
ACTIONS_ENABLED=true
ACTIONS_ALLOWED="selected"
ACTIONS_GITHUB_OWNED=true
ACTIONS_VERIFIED=false
WORKFLOW_DEFAULT_PERMISSION="read"
WORKFLOW_CAN_APPROVE_PR=false

# Immutable releases
ENABLE_IMMUTABLE_RELEASES=true
IMMUTABLE_TAGS_PATTERN="v*"

TEXT_HELPER="
This script configures GitHub repository settings and security best practices using the REST API.
It complements github-create-ruleset.sh (branch protection) and github-create-app.sh (app creation).

Configured settings:
  - Repository merge strategy and general settings
  - Vulnerability alerts and automated security fixes (Dependabot)
  - Private vulnerability reporting
  - Secret scanning and push protection
  - GitHub Actions permissions and default workflow permissions
  - Immutable releases via tag rulesets

Available flags:
  -o    Owner (organization or user). [required]
  -r    Repository name. [required]
  -t    GitHub Personal Access Token. [required]

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
  -x    Enable automated security fixes (Dependabot auto-PRs).
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
  -g    When actions_allowed=selected, allow GitHub-owned actions.
        Default: '$ACTIONS_GITHUB_OWNED'.
  -e    When actions_allowed=selected, allow verified creator actions.
        Default: '$ACTIONS_VERIFIED'.
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
    -t 'ghp_xxx'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

log_step() {
  printf "\n${COLOR_BLUE}==> $1${COLOR_OFF}\n"
}

log_success() {
  printf "${COLOR_GREEN}✔ $1${COLOR_OFF}\n"
}

log_warn() {
  printf "${COLOR_YELLOW}⚠ $1${COLOR_OFF}\n"
}

log_error() {
  printf "${COLOR_RED}✖ $1${COLOR_OFF}\n"
}

# Perform a curl call and return the response body.
# Exits with error if the HTTP status is >= 400.
github_api() {
  local method="$1"
  local url="$2"
  local data="${3:-}"

  local http_response
  local http_body
  local http_status

  if [ -n "$data" ]; then
    http_response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -d "$data")
  else
    http_response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28")
  fi

  http_status=$(echo "$http_response" | tail -n1)
  http_body=$(echo "$http_response" | sed '$d')

  if [ "$http_status" -ge 400 ]; then
    log_error "API call failed (HTTP $http_status): $method $url"
    echo "$http_body" | jq -r '.message // .' 2>/dev/null || echo "$http_body"
    return 1
  fi

  echo "$http_body"
}

# Parse options
while getopts "ho:r:t:D:S:M:R:A:U:w:j:I:G:v:x:V:s:P:a:g:e:W:p:i:T:" flag; do
  case "${flag}" in
    o) OWNER=${OPTARG};;
    r) REPO=${OPTARG};;
    t) TOKEN=${OPTARG};;
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
    g) ACTIONS_GITHUB_OWNED=${OPTARG};;
    e) ACTIONS_VERIFIED=${OPTARG};;
    W) WORKFLOW_DEFAULT_PERMISSION=${OPTARG};;
    p) WORKFLOW_CAN_APPROVE_PR=${OPTARG};;
    i) ENABLE_IMMUTABLE_RELEASES=${OPTARG};;
    T) IMMUTABLE_TAGS_PATTERN=${OPTARG};;
    h | *) print_help; exit 0;;
  esac
done

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
  > ACTIONS_GITHUB_OWNED: ${ACTIONS_GITHUB_OWNED}
  > ACTIONS_VERIFIED: ${ACTIONS_VERIFIED}
  > WORKFLOW_DEFAULT_PERMISSION: ${WORKFLOW_DEFAULT_PERMISSION}
  > WORKFLOW_CAN_APPROVE_PR: ${WORKFLOW_CAN_APPROVE_PR}

  Immutable releases:
  > ENABLE_IMMUTABLE_RELEASES: ${ENABLE_IMMUTABLE_RELEASES}
  > IMMUTABLE_TAGS_PATTERN: ${IMMUTABLE_TAGS_PATTERN}
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

if [[ "$ACTIONS_ALLOWED" != "all" && "$ACTIONS_ALLOWED" != "local_only" && "$ACTIONS_ALLOWED" != "selected" ]]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for -a: must be 'all', 'local_only', or 'selected'.\n"
  exit 1
fi

if [[ "$WORKFLOW_DEFAULT_PERMISSION" != "read" && "$WORKFLOW_DEFAULT_PERMISSION" != "write" ]]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid value for -W: must be 'read' or 'write'.\n"
  exit 1
fi

BASE_URL="https://api.github.com/repos/$OWNER/$REPO"

# ─────────────────────────────────────────────
# 1. Repository general settings
# ─────────────────────────────────────────────
log_step "Configuring repository general settings..."

# Build security_and_analysis block conditionally (only available for eligible repos)
SECRET_SCANNING_STATUS=$([ "$ENABLE_SECRET_SCANNING" = "true" ] && echo "enabled" || echo "disabled")
PUSH_PROTECTION_STATUS=$([ "$ENABLE_SECRET_SCANNING_PUSH_PROTECTION" = "true" ] && echo "enabled" || echo "disabled")

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
  --arg ss_status "$SECRET_SCANNING_STATUS" \
  --arg pp_status "$PUSH_PROTECTION_STATUS" \
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
    web_commit_signoff_required: $signoff,
    security_and_analysis: {
      secret_scanning: {status: $ss_status},
      secret_scanning_push_protection: {status: $pp_status}
    }
  }')

if github_api PATCH "$BASE_URL" "$REPO_PAYLOAD" > /dev/null; then
  log_success "Repository general settings applied."
else
  log_warn "Repository settings partially applied (secret scanning may require GitHub Advanced Security)."
fi

# ─────────────────────────────────────────────
# 2. Vulnerability alerts (Dependabot)
# ─────────────────────────────────────────────
log_step "Configuring vulnerability alerts..."

if [ "$ENABLE_VULNERABILITY_ALERTS" = "true" ]; then
  if github_api PUT "$BASE_URL/vulnerability-alerts" > /dev/null; then
    log_success "Vulnerability alerts enabled."
  fi
else
  if github_api DELETE "$BASE_URL/vulnerability-alerts" > /dev/null; then
    log_success "Vulnerability alerts disabled."
  fi
fi

# ─────────────────────────────────────────────
# 3. Automated security fixes (Dependabot PRs)
# ─────────────────────────────────────────────
log_step "Configuring automated security fixes..."

if [ "$ENABLE_AUTOMATED_SECURITY_FIXES" = "true" ]; then
  if github_api PUT "$BASE_URL/automated-security-fixes" > /dev/null; then
    log_success "Automated security fixes enabled."
  fi
else
  if github_api DELETE "$BASE_URL/automated-security-fixes" > /dev/null; then
    log_success "Automated security fixes disabled."
  fi
fi

# ─────────────────────────────────────────────
# 4. Private vulnerability reporting
# ─────────────────────────────────────────────
log_step "Configuring private vulnerability reporting..."

if [ "$ENABLE_PRIVATE_VULNERABILITY_REPORTING" = "true" ]; then
  if github_api PUT "$BASE_URL/private-vulnerability-reporting" > /dev/null; then
    log_success "Private vulnerability reporting enabled."
  fi
else
  if github_api DELETE "$BASE_URL/private-vulnerability-reporting" > /dev/null; then
    log_success "Private vulnerability reporting disabled."
  fi
fi

# ─────────────────────────────────────────────
# 5. GitHub Actions permissions
# ─────────────────────────────────────────────
log_step "Configuring GitHub Actions permissions..."

ACTIONS_PAYLOAD=$(jq -n \
  --argjson enabled "$ACTIONS_ENABLED" \
  --arg allowed "$ACTIONS_ALLOWED" \
  '{enabled: $enabled, allowed_actions: $allowed}')

if github_api PUT "$BASE_URL/actions/permissions" "$ACTIONS_PAYLOAD" > /dev/null; then
  log_success "Actions permissions set (allowed: $ACTIONS_ALLOWED)."
fi

# Configure selected actions allowlist when mode is 'selected'
if [ "$ACTIONS_ALLOWED" = "selected" ]; then
  SELECTED_PAYLOAD=$(jq -n \
    --argjson github_owned "$ACTIONS_GITHUB_OWNED" \
    --argjson verified "$ACTIONS_VERIFIED" \
    '{github_owned_allowed: $github_owned, verified_allowed: $verified, patterns_allowed: []}')

  if github_api PUT "$BASE_URL/actions/permissions/selected-actions" "$SELECTED_PAYLOAD" > /dev/null; then
    log_success "Selected actions configured (github_owned=$ACTIONS_GITHUB_OWNED, verified=$ACTIONS_VERIFIED)."
  fi
fi

# ─────────────────────────────────────────────
# 6. Default workflow permissions (GITHUB_TOKEN)
# ─────────────────────────────────────────────
log_step "Configuring default workflow permissions..."

WORKFLOW_PAYLOAD=$(jq -n \
  --arg perm "$WORKFLOW_DEFAULT_PERMISSION" \
  --argjson can_approve "$WORKFLOW_CAN_APPROVE_PR" \
  '{default_workflow_permissions: $perm, can_approve_pull_request_reviews: $can_approve}')

if github_api PUT "$BASE_URL/actions/permissions/workflow" "$WORKFLOW_PAYLOAD" > /dev/null; then
  log_success "Default workflow permissions set (${WORKFLOW_DEFAULT_PERMISSION}, can_approve_pr=${WORKFLOW_CAN_APPROVE_PR})."
fi

# ─────────────────────────────────────────────
# 7. Immutable releases (tag ruleset)
# ─────────────────────────────────────────────
log_step "Configuring immutable releases..."

if [ "$ENABLE_IMMUTABLE_RELEASES" = "true" ]; then
  TAG_INCLUDE_PATTERN="refs/tags/${IMMUTABLE_TAGS_PATTERN}"

  # Check whether an immutable-releases ruleset already exists to avoid duplicates
  EXISTING_RULESETS=$(github_api GET "$BASE_URL/rulesets" || echo "[]")
  EXISTING_ID=$(echo "$EXISTING_RULESETS" | jq -r '.[] | select(.name == "Immutable releases") | .id' 2>/dev/null | head -n1)

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

  if [ -n "$EXISTING_ID" ]; then
    if github_api PUT "$BASE_URL/rulesets/$EXISTING_ID" "$RULESET_PAYLOAD" > /dev/null; then
      log_success "Immutable releases ruleset updated (id=$EXISTING_ID, pattern=$TAG_INCLUDE_PATTERN)."
    fi
  else
    RULESET_RESPONSE=$(github_api POST "$BASE_URL/rulesets" "$RULESET_PAYLOAD")
    RULESET_ID=$(echo "$RULESET_RESPONSE" | jq -r '.id // empty')
    if [ -n "$RULESET_ID" ]; then
      log_success "Immutable releases ruleset created (id=$RULESET_ID, pattern=$TAG_INCLUDE_PATTERN)."
    fi
  fi
else
  log_warn "Immutable releases disabled — skipping tag ruleset."
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
printf "\n${COLOR_GREEN}Repository '$OWNER/$REPO' configured successfully.${COLOR_OFF}\n"

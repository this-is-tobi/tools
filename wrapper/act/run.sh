#!/bin/bash

set -euo pipefail

# Versions
# act release installed when act is missing
ACT_VERSION="0.2.89"

# Runner image
# Served for every GitHub-hosted ubuntu label below (override with ACT_RUNNER_IMAGE).
DEFAULT_RUNNER_IMAGE="ghcr.io/this-is-tobi/tools/act-runner:latest"
RUNNER_LABELS="ubuntu-latest ubuntu-26.04 ubuntu-24.04 ubuntu-22.04"

# Colors, only on a terminal (https://no-color.org)
if [ -t 1 ] && [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  COLOR_CYAN='\033[0;36m'
  COLOR_RED='\033[0;31m'
  COLOR_YELLOW='\033[0;33m'
  COLOR_OFF='\033[0m'
else
  COLOR_CYAN=''
  COLOR_RED=''
  COLOR_YELLOW=''
  COLOR_OFF=''
fi

# Logging
log() { printf '\n%b[act]%b %s\n' "$COLOR_CYAN" "$COLOR_OFF" "$*"; }
warn() { printf '%b[act]%b %s\n' "$COLOR_YELLOW" "$COLOR_OFF" "$*" >&2; }
die() { printf '%b[act]%b %s\n' "$COLOR_RED" "$COLOR_OFF" "$*" >&2; exit 1; }

# Paths
# This script sits at the root of the act directory, inside the project: act
# always starts from the project root, wherever the script is called from.
ACT_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
PROJECT_ROOT="$(git -C "$ACT_DIR" rev-parse --show-toplevel 2> /dev/null || dirname "$ACT_DIR")"
ACT_ENV_FILE="$ACT_DIR/env/.env"
REGISTRY_DIR="$ACT_DIR/registry"

# Run id, also the name of the artifacts folder
NOW=$(date +'%Y-%m-%dT%H-%M-%S')

# Defaults
ASSUME_YES="false"
EVENT_FILE="$ACT_DIR/events/pr_base_main.json"
JOB=""
LIST_ONLY="false"
START_REGISTRY="false"
WORKFLOW_PATH="$PROJECT_ROOT/.github/workflows"

# Script helper
TEXT_HELPER="
This script aims to run the GitHub Actions workflows of a project locally, using act.

It can be called from anywhere in the project: act always runs from the project
root ('$PROJECT_ROOT'), where it also reads
the optional .actrc, .secrets, .env and .vars files.

Available flags:
  -e  Event file that triggers the workflows.
      Default: '$EVENT_FILE'.
  -j  Run a single job, given its id (e.g. 'lint').
  -l  List workflows, jobs and their graph for the event, then exit without running anything.
  -r  Start a local docker registry for the run, reachable on 127.0.0.1 only and stopped when it ends.
  -w  Workflow file or directory.
      Default: '$WORKFLOW_PATH'.
  -y  Install act without asking when it is missing.
  -h  Print script help.

Anything after '--' is handed to act as is.

Settings read from the environment, or from '$ACT_ENV_FILE' (see 'env/.env-example'):
  ACT_RUNNER_IMAGE   Image the ubuntu-* jobs run in.
                     Default: '$DEFAULT_RUNNER_IMAGE'.
  REGISTRY_HOST, REGISTRY_PORT, REGISTRY_USERNAME, REGISTRY_SECRET
                     Local registry settings (-r). The username and secret have no default and are
                     handed to act by name, so their values never appear in the process list.

Examples:
  ./act/run.sh
  ./act/run.sh -j lint
  ./act/run.sh -w .github/workflows/ci.yml -e act/events/push_base_main.json
  ./act/run.sh -r
  ./act/run.sh -- --container-architecture linux/amd64
"

print_help() {
  printf '%b\n' "$TEXT_HELPER"
}

# Functions
# Absolute path of a file or directory that may not exist yet (relative paths are
# resolved against the directory the script was called from).
abs_path() {
  local dir
  if dir="$(cd -- "$(dirname -- "$1")" 2> /dev/null && pwd -P)"; then
    printf '%s/%s' "${dir%/}" "$(basename -- "$1")"
  else
    printf '%s' "$1"
  fi
}

need() {
  command -v "$1" > /dev/null 2>&1 || die "$1 is required: $2"
}

sha256() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

# Installs a pinned act release after checking it against the release checksums,
# instead of piping a remote install script into a root shell.
install_act() {
  log "Install act v${ACT_VERSION}"

  local arch
  local asset
  local download_dir
  local expected
  case "$(uname -m)" in
    x86_64) arch="x86_64";;
    arm64 | aarch64) arch="arm64";;
    *) die "No act binary for architecture '$(uname -m)', see https://github.com/nektos/act.";;
  esac
  asset="act_$(uname -s)_${arch}.tar.gz"

  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/act-install.XXXXXX")"
  curl -fsSL -o "$download_dir/$asset" "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/${asset}"
  curl -fsSL -o "$download_dir/checksums.txt" "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/checksums.txt"
  expected="$(awk -v a="$asset" '$2 == a { print $1 }' "$download_dir/checksums.txt")"
  if [ -z "$expected" ] || [ "$(sha256 "$download_dir/$asset")" != "$expected" ]; then
    rm -rf "$download_dir"
    die "Checksum mismatch for $asset, nothing was installed."
  fi

  tar -xzf "$download_dir/$asset" -C "$download_dir" act
  sudo install -d /usr/local/bin
  sudo install -m 0755 "$download_dir/act" /usr/local/bin/act
  rm -rf "$download_dir"

  log "$(act --version) installed"
}

ensure_act() {
  command -v act > /dev/null 2>&1 && return 0
  if [ "$ASSUME_YES" != "true" ]; then
    [ -t 0 ] || die "act is not installed: run 'brew install act', or call this script with -y to install v${ACT_VERSION}."
    local answer
    while true; do
      read -r -p "act is not installed. Install v${ACT_VERSION} in /usr/local/bin (sudo)? [y/n] " answer
      case "$answer" in
        [Yy]*) break;;
        [Nn]*) die "act is required: run 'brew install act' or see https://github.com/nektos/act.";;
        *) echo "Please answer yes or no.";;
      esac
    done
  fi
  install_act
}

# Everything after '--' is handed to act untouched
EXTRA_ARGS=()
for ((n = 1; n <= $#; n++)); do
  if [ "${!n}" = "--" ]; then
    EXTRA_ARGS=("${@:n+1}")
    set -- "${@:1:n-1}"
    break
  fi
done

# Parse options
while getopts he:j:lrw:y flag; do
  case "${flag}" in
    e)
      EVENT_FILE="$(abs_path "${OPTARG}")";;
    j)
      JOB="${OPTARG}";;
    l)
      LIST_ONLY="true";;
    r)
      START_REGISTRY="true";;
    w)
      WORKFLOW_PATH="$(abs_path "${OPTARG}")";;
    y)
      ASSUME_YES="true";;
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
  warn "Unexpected argument: '$1' (arguments for act go after '--')."
  print_help >&2
  exit 1
fi

# Env & secrets
if [ -f "$ACT_ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ACT_ENV_FILE"
  set +a
fi
ACT_RUNNER_IMAGE="${ACT_RUNNER_IMAGE:-$DEFAULT_RUNNER_IMAGE}"
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5555}"
REGISTRY_PORT="${REGISTRY_PORT:-5555}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_SECRET="${REGISTRY_SECRET:-}"
export REGISTRY_HOST REGISTRY_PORT REGISTRY_USERNAME REGISTRY_SECRET

# Options validation
if [ ! -e "$WORKFLOW_PATH" ]; then
  warn "Workflow path '$WORKFLOW_PATH' does not exist (use -w to point to another file or directory)."
  exit 1
fi
if [ ! -f "$EVENT_FILE" ]; then
  warn "Event file '$EVENT_FILE' does not exist (available ones are in '$ACT_DIR/events')."
  exit 1
fi
if [ "$START_REGISTRY" = "true" ] && { [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_SECRET" ]; }; then
  die "The local registry needs REGISTRY_USERNAME and REGISTRY_SECRET: set them in '$ACT_ENV_FILE' or in the environment."
fi

# Prerequisites
ensure_act
need jq "brew install jq"
EVENT_NAME=$(jq -r 'keys_unsorted | first' "$EVENT_FILE")

# act starts from the project root: that is the workspace the jobs see
cd "$PROJECT_ROOT"

if [ "$LIST_ONLY" = "true" ]; then
  act "$EVENT_NAME" --workflows "$WORKFLOW_PATH" --eventpath "$EVENT_FILE" --list
  act "$EVENT_NAME" --workflows "$WORKFLOW_PATH" --eventpath "$EVENT_FILE" --graph
  exit 0
fi

docker info > /dev/null 2>&1 || die "Docker is not running: start Docker Desktop (or your container engine) and try again."

log "$(act --version) | event: $EVENT_NAME ($EVENT_FILE) | workflows: $WORKFLOW_PATH | runner: $ACT_RUNNER_IMAGE"


if [ "$START_REGISTRY" = "true" ]; then
  need openssl "brew install openssl"
  docker compose version > /dev/null 2>&1 || die "The local registry needs docker compose."

  log "Create certificate for local registry"

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$REGISTRY_DIR/certs/registry.local.key" -out "$REGISTRY_DIR/certs/registry.local.crt" \
    -subj "/C=FR/ST=France/L=Paris/O=IT/CN=registry.local"


  log "Add local certificate for the registry"

  if [ -w /etc/ssl/certs ]; then
    cp "$REGISTRY_DIR/certs/registry.local.crt" /etc/ssl/certs/registry.local
  else
    warn "Skipped: /etc/ssl/certs is not writable by the current user."
  fi


  log "Add the registry in docker daemon insecure registries"

  if [ -f "$HOME/.docker/daemon.json" ]; then
    DAEMON_TMP="$(mktemp "$HOME/.docker/daemon.json.XXXXXX")"
    jq --arg registry "$REGISTRY_HOST" '."insecure-registries" = ((."insecure-registries" // []) + [$registry] | unique)' \
      "$HOME/.docker/daemon.json" > "$DAEMON_TMP"
    mv "$DAEMON_TMP" "$HOME/.docker/daemon.json"
  else
    warn "Skipped: no '$HOME/.docker/daemon.json' file."
  fi


  log "Create credentials for local registry"

  # htpasswd reads the password on stdin (-i) so it stays out of the process list
  printf '%s\n' "$REGISTRY_SECRET" | docker run \
    --rm \
    -i \
    --entrypoint htpasswd \
    httpd:2 -iBn "$REGISTRY_USERNAME" \
    > "$REGISTRY_DIR/auth/htpasswd"

  log "Start local registry"

  # Stopped on exit, whatever the outcome of the workflows
  trap 'log "Stop local registry"; docker compose -f "$REGISTRY_DIR/docker-compose.registry.yml" down -v' EXIT
  docker compose -f "$REGISTRY_DIR/docker-compose.registry.yml" up -d
fi


log "Run workflows"

ACT_ARGS=(
  "$EVENT_NAME"
  --workflows "$WORKFLOW_PATH"
  --eventpath "$EVENT_FILE"
  --artifact-server-path "$ACT_DIR/artifacts"
  --env "GITHUB_RUN_ID=$NOW"
  --env "REGISTRY_HOST=$REGISTRY_HOST"
  --env "REGISTRY_PORT=$REGISTRY_PORT"
  # The image is only pulled when it is missing locally: 'docker pull' refreshes it.
  --pull=false
  --rm
)
for LABEL in $RUNNER_LABELS; do
  ACT_ARGS+=(--platform "$LABEL=$ACT_RUNNER_IMAGE")
done
if [ -n "$JOB" ]; then
  ACT_ARGS+=(--job "$JOB")
fi
# '--secret NAME' without a value makes act read the variable from its environment.
for SECRET_NAME in REGISTRY_USERNAME REGISTRY_SECRET; do
  if [ -n "${!SECRET_NAME}" ]; then
    ACT_ARGS+=(--secret "$SECRET_NAME")
  fi
done

# A failing workflow must not skip the artifacts retrieval: its status is returned at the end.
ACT_STATUS=0
act "${ACT_ARGS[@]}" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"} || ACT_STATUS=$?


if [ -d "$ACT_DIR/artifacts/$NOW" ]; then
  log "Retrieve artifacts"

  find "$ACT_DIR/artifacts/$NOW" -type f -name "*.gz__" | while IFS= read -r f; do
    mv -- "$f" "${f%.gz__}.gz"
    gunzip "${f%.gz__}.gz"
  done
  printf 'Artifacts: %s\n' "$ACT_DIR/artifacts/$NOW"
fi

exit "$ACT_STATUS"

#!/bin/bash

set -euo pipefail

# Colors
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_OFF='\033[0m'
# Console step increment
i=1

# Versions
# act release installed when act is missing
ACT_VERSION="0.2.89"

# Get project directories
# This script lives in '<act directory>/scripts'.
ACT_DIR="$(cd -- "$(dirname "$0")/.." > /dev/null 2>&1; pwd -P)"
ACT_ENV_FILE="${ACT_DIR}/env/.env"
REGISTRY_DIR="$ACT_DIR/registry"

# Get Date
NOW=$(date +'%Y-%m-%dT%H-%M-%S')

# Defaults
EVENT_FILE="$ACT_DIR/events/pr_base_main.json"
START_REGISTRY="false"
WORKFLOW_DIR="$ACT_DIR/workflows/"

# Script helper
TEXT_HELPER="\nThis script aims to run CI locally for tests.
Following flags are available:

  -e    (Optional) Event file that will trigger workflows. e.g: '$ACT_DIR/events/push_base_main.json'.
        Default is '$EVENT_FILE'.

  -r    (Optional) Start a local registry running as a docker container, reachable on 127.0.0.1 only.
        Default is '$START_REGISTRY'.

  -w    (Optional) Workflow directory or file that will be triggered. e.g: './.github/workflows' or './.github/workflows/test.yml'.
        Default is '$WORKFLOW_DIR'.

  -h    Print script help.

Registry settings (REGISTRY_HOST, REGISTRY_PORT, REGISTRY_USERNAME, REGISTRY_SECRET) are
read from the environment and from '$ACT_ENV_FILE' (see 'env/.env-example').
REGISTRY_USERNAME and REGISTRY_SECRET are handed to act by name, so their values never
appear in the process list.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts he:rw: flag; do
  case "${flag}" in
    e)
      EVENT_FILE="$(readlink -f "${OPTARG}")";;
    r)
      START_REGISTRY="true";;
    w)
      WORKFLOW_DIR="$(readlink -f "${OPTARG}")";;
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

# utils
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
  printf "\n\n${COLOR_RED}Optional.${COLOR_OFF} Installs act v%s...\n\n" "$ACT_VERSION"

  local arch
  local asset
  local download_dir
  local expected
  case "$(uname -m)" in
    x86_64) arch="x86_64";;
    arm64 | aarch64) arch="arm64";;
    *)
      printf "\nNo act binary for architecture '%s', see https://github.com/nektos/act.\n" "$(uname -m)" >&2
      exit 1;;
  esac
  asset="act_$(uname -s)_${arch}.tar.gz"

  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/act-install.XXXXXX")"
  curl -fsSL -o "$download_dir/$asset" "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/${asset}"
  curl -fsSL -o "$download_dir/checksums.txt" "https://github.com/nektos/act/releases/download/v${ACT_VERSION}/checksums.txt"
  expected="$(awk -v a="$asset" '$2 == a { print $1 }' "$download_dir/checksums.txt")"
  if [ -z "$expected" ] || [ "$(sha256 "$download_dir/$asset")" != "$expected" ]; then
    rm -rf "$download_dir"
    printf "\n${COLOR_RED}Error.${COLOR_OFF} Checksum mismatch for %s, nothing was installed.\n" "$asset" >&2
    exit 1
  fi

  tar -xzf "$download_dir/$asset" -C "$download_dir" act
  sudo install -d /usr/local/bin
  sudo install -m 0755 "$download_dir/act" /usr/local/bin/act
  rm -rf "$download_dir"

  printf "\n\nact version %s installed\n\n" "$(act --version)"
}

if ! command -v act > /dev/null 2>&1; then
  while true; do
    read -r -p "You need act to run this script. Do you wish to install act? [y/n] " yn
    case $yn in
      [Yy]*)
        install_act
        break;;
      [Nn]*)
        exit 1;;
      *)
        echo "Please answer yes or no.";;
    esac
  done
fi


# Env & secrets
if [ -f "$ACT_ENV_FILE" ]; then
  set -a
  # shellcheck source=/dev/null
  . "$ACT_ENV_FILE"
  set +a
fi
REGISTRY_HOST="${REGISTRY_HOST:-localhost:5555}"
REGISTRY_PORT="${REGISTRY_PORT:-5555}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_SECRET="${REGISTRY_SECRET:-}"
export REGISTRY_HOST REGISTRY_PORT REGISTRY_USERNAME REGISTRY_SECRET


# Script condition
if [ ! -e "$WORKFLOW_DIR" ]; then
  printf "\n\nWorkflow directory '%s' does not exist.\n\n" "$WORKFLOW_DIR" >&2
  print_help >&2
  exit 1
fi
if [ ! -f "$EVENT_FILE" ]; then
  printf "\n\nEvent file '%s' does not exist.\n\n" "$EVENT_FILE" >&2
  print_help >&2
  exit 1
fi
if [ "$START_REGISTRY" = "true" ] && { [ -z "$REGISTRY_USERNAME" ] || [ -z "$REGISTRY_SECRET" ]; }; then
  printf "\n\nThe local registry needs REGISTRY_USERNAME and REGISTRY_SECRET: set them in '%s' or in the environment.\n\n" "$ACT_ENV_FILE" >&2
  exit 1
fi

# Settings
EVENT_NAME=$(jq -r 'keys_unsorted | first' "$EVENT_FILE")
printf "\n\nScript settings:
  -> act version: %s
  -> docker version: %s
  -> docker-compose version: %s
  -> workflows directory: %s
  -> event file: %s
  -> event name: %s\n\n" \
  "$(act --version)" "$(docker --version)" "$(docker compose version)" "$WORKFLOW_DIR" "$EVENT_FILE" "$EVENT_NAME"


if [ "$START_REGISTRY" = "true" ]; then
  printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Create certificate for local registry\n\n"
  i=$((i + 1))

  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout "$REGISTRY_DIR/certs/registry.local.key" -out "$REGISTRY_DIR/certs/registry.local.crt" \
    -subj "/C=FR/ST=France/L=Paris/O=IT/CN=registry.local"


  printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Add local certificate for the registry\n\n"
  i=$((i + 1))

  if [ -w /etc/ssl/certs ]; then
    cp "$REGISTRY_DIR/certs/registry.local.crt" /etc/ssl/certs/registry.local
  else
    printf "${COLOR_YELLOW}Skipped:${COLOR_OFF} /etc/ssl/certs is not writable by the current user.\n"
  fi


  printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Add the registry in docker daemon insecure registries\n\n"
  i=$((i + 1))

  if [ -f "$HOME/.docker/daemon.json" ]; then
    DAEMON_TMP="$(mktemp "$HOME/.docker/daemon.json.XXXXXX")"
    jq --arg registry "$REGISTRY_HOST" '."insecure-registries" = ((."insecure-registries" // []) + [$registry] | unique)' \
      "$HOME/.docker/daemon.json" > "$DAEMON_TMP"
    mv "$DAEMON_TMP" "$HOME/.docker/daemon.json"
  else
    printf "${COLOR_YELLOW}Skipped:${COLOR_OFF} no '%s' file.\n" "$HOME/.docker/daemon.json"
  fi


  printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Create credentials for local registry\n\n"
  i=$((i + 1))

  # htpasswd reads the password on stdin (-i) so it stays out of the process list
  printf '%s\n' "$REGISTRY_SECRET" | docker run \
    --rm \
    -i \
    --entrypoint htpasswd \
    httpd:2 -iBn "$REGISTRY_USERNAME" \
    > "$REGISTRY_DIR/auth/htpasswd"

  printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Start local registry\n\n"
  i=$((i + 1))

  # Stopped on exit, whatever the outcome of the workflows
  trap 'printf "\n\n${COLOR_RED}Stop local registry${COLOR_OFF}\n\n"; docker compose -f "$REGISTRY_DIR/docker-compose.registry.yml" down -v' EXIT
  docker compose -f "$REGISTRY_DIR/docker-compose.registry.yml" up -d
fi


printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Displays workflow list\n\n"
i=$((i + 1))

act \
  --workflows "$WORKFLOW_DIR" \
  --eventpath "$EVENT_FILE" \
  --list


printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Displays workflow graph\n\n"
i=$((i + 1))

act \
  --workflows "$WORKFLOW_DIR" \
  --eventpath "$EVENT_FILE" \
  --graph


printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Runs locally GitHub Actions workflow\n\n"
i=$((i + 1))

# '--secret NAME' without a value makes act read the variable from its environment.
SECRET_ARGS=()
for SECRET_NAME in REGISTRY_USERNAME REGISTRY_SECRET; do
  if [ -n "${!SECRET_NAME}" ]; then
    SECRET_ARGS+=(--secret "$SECRET_NAME")
  fi
done

# A failing workflow must not skip the artifacts retrieval: its status is returned at the end.
ACT_STATUS=0
act "$EVENT_NAME" \
  --platform "ubuntu-latest=ghcr.io/this-is-tobi/tools/act-runner:latest" \
  --workflows "$WORKFLOW_DIR" \
  --eventpath "$EVENT_FILE" \
  --use-gitignore \
  --artifact-server-path "$ACT_DIR/artifacts" \
  --env "GITHUB_RUN_ID=$NOW" \
  --env "REGISTRY_HOST=$REGISTRY_HOST" \
  --env "REGISTRY_PORT=$REGISTRY_PORT" \
  ${SECRET_ARGS[@]+"${SECRET_ARGS[@]}"} \
  --rm || ACT_STATUS=$?
  # --bind \


printf "\n\n${COLOR_RED}${i}.${COLOR_OFF} Retrieves artifacts\n\n"
i=$((i + 1))

if [ -d "$ACT_DIR/artifacts/$NOW" ]; then
  find "$ACT_DIR/artifacts/$NOW" -type f -name "*.gz__" | while IFS= read -r f; do
    mv -- "$f" "${f%.gz__}.gz"
    gunzip "${f%.gz__}.gz"
  done
fi

exit "$ACT_STATUS"

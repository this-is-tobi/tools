#!/bin/bash

set -euo pipefail

# Versions
KIND_VERSION="0.33.0"
# configs/traefik-values.yml follows the schema of this chart version: bump both together.
TRAEFIK_CHART_VERSION="42.3.1"

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
log() { printf '\n%b[kind]%b %s\n' "$COLOR_CYAN" "$COLOR_OFF" "$*"; }
warn() { printf '%b[kind]%b %s\n' "$COLOR_YELLOW" "$COLOR_OFF" "$*" >&2; }
die() { printf '%b[kind]%b %s\n' "$COLOR_RED" "$COLOR_OFF" "$*" >&2; exit 1; }

# Paths
# This script sits at the root of the kind directory, inside the project: every
# command runs from the project root, wherever the script is called from. That
# is the directory mounted in the cluster node (see configs/kind-config.yml).
KIND_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
PROJECT_ROOT="$(git -C "$KIND_DIR" rev-parse --show-toplevel 2> /dev/null || dirname "$KIND_DIR")"

# Defaults
ASSUME_YES="false"
CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"
COMMANDS=""
COMPOSE_FILE="$KIND_DIR/docker-compose.yml"
DOMAINS=""
TAG=""
KNOWN_COMMANDS="create build load deploy clean delete dev prod"

# Script helper
TEXT_HELPER="
This script aims to manage a local kubernetes cluster using Kind, also known as Kubernetes in Docker.

Usage:
  ./kind/run.sh <command>... [flags]

Available commands:
  dev     Create the cluster, build and load the images, then deploy the application in dev mode.
  prod    Same as dev, deploying the application in prod mode.
  create  Create the cluster and its Traefik ingress controller.
  build   Build the images of the compose file and load them into the cluster.
  load    Load the images of the compose file into the cluster.
  deploy  Deploy the application in dev mode (runs hooks/deploy.sh).
  clean   Remove the application from the cluster (runs hooks/clean.sh).
  delete  Delete the cluster.

Several commands can be given, e.g. './kind/run.sh create build'.

Available flags:
  -c    Commands as a comma separated list, e.g. 'create,build' (older syntax of the arguments above).
  -d    Domains to add to /etc/hosts for local services resolution, as a comma separated list (needs sudo).
  -f    Docker compose file declaring the images to build.
        Default: '$COMPOSE_FILE'.
  -n    Name of the cluster. The kubectl context is 'kind-<name>'.
        Default: '$CLUSTER_NAME' (or KIND_CLUSTER_NAME).
  -t    Tag handed to the deploy hook as IMAGE_TAG.
  -y    Install kind without asking when it is missing.
  -h    Print script help.

Examples:
  ./kind/run.sh dev
  ./kind/run.sh dev -d 'api.domain.local,doc.domain.local'
  ./kind/run.sh create
  ./kind/run.sh delete
"

print_help() {
  printf '%b\n' "$TEXT_HELPER"
}

# Functions
# Absolute path of a file that may not exist yet (relative paths are resolved
# against the directory the script was called from).
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

# Installs a pinned kind release after checking its sha256, instead of piping a
# remote install script into a root shell.
install_kind() {
  log "Install kind v${KIND_VERSION}"

  local arch
  local os
  case "$(uname)" in
    Linux) os="linux";;
    Darwin) os="darwin";;
    *) die "No kind binary for your system, see https://kind.sigs.k8s.io/docs/user/quick-start/#installation.";;
  esac
  case "$(uname -m)" in
    x86_64) arch="amd64";;
    arm64 | aarch64) arch="arm64";;
    *) die "No kind binary for architecture '$(uname -m)', see https://kind.sigs.k8s.io/docs/user/quick-start/#installation.";;
  esac

  # Download and check the binary before anything gets installed
  local download_dir
  local base_url="https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-${os}-${arch}"
  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/kind-install.XXXXXX")"
  curl -fsSL -o "$download_dir/kind" "$base_url"
  curl -fsSL -o "$download_dir/kind.sha256sum" "$base_url.sha256sum"
  if [ "$(sha256 "$download_dir/kind")" != "$(cut -d ' ' -f 1 "$download_dir/kind.sha256sum")" ]; then
    rm -rf "$download_dir"
    die "Checksum mismatch for kind v${KIND_VERSION}, nothing was installed."
  fi
  sudo install -d /usr/local/bin
  sudo install -m 0755 "$download_dir/kind" /usr/local/bin/kind
  rm -rf "$download_dir"

  log "$(kind --version) installed"
}

ensure_kind() {
  command -v kind > /dev/null 2>&1 && return 0
  if [ "$ASSUME_YES" != "true" ]; then
    [ -t 0 ] || die "kind is not installed: run 'brew install kind', or call this script with -y to install v${KIND_VERSION}."
    local answer
    while true; do
      read -r -p "kind is not installed. Install v${KIND_VERSION} in /usr/local/bin (sudo)? [y/n] " answer
      case "$answer" in
        [Yy]*) break;;
        [Nn]*) die "kind is required: run 'brew install kind' or see https://kind.sigs.k8s.io/docs/user/quick-start/#installation.";;
        *) echo "Please answer yes or no.";;
      esac
    done
  fi
  install_kind
}

# Runs hooks/<name>.sh from the project root, if the project has one. Hooks are
# the project's own code: this script stays untouched when it is updated.
run_hook() {
  local name="$1"
  shift
  local hook="$KIND_DIR/hooks/$name.sh"
  if [ ! -f "$hook" ]; then
    warn "No hooks/$name.sh, nothing to run."
    return 0
  fi
  log "Run hooks/$name.sh"
  KIND_CLUSTER_NAME="$CLUSTER_NAME" KUBE_CONTEXT="$KUBE_CONTEXT" PROJECT_ROOT="$PROJECT_ROOT" IMAGE_TAG="$TAG" bash "$hook" "$@"
}

# Installs Traefik unless it is already there, so running the command again
# repairs a cluster whose first installation failed halfway.
install_ingress () {
  if helm --kube-context "$KUBE_CONTEXT" list --namespace ingress-traefik --deployed --short 2> /dev/null | grep -qx traefik; then
    return 0
  fi
  log "Install traefik ingress controller"
  helm repo add traefik https://traefik.github.io/charts --force-update
  helm repo update traefik
  helm --kube-context "$KUBE_CONTEXT" upgrade \
    --install \
    --wait \
    --namespace ingress-traefik \
    --create-namespace \
    --version "$TRAEFIK_CHART_VERSION" \
    --values "$KIND_DIR/configs/traefik-values.yml" \
    traefik traefik/traefik
}

create () {
  if kind get clusters 2> /dev/null | grep -qx "$CLUSTER_NAME"; then
    log "Kind cluster '$CLUSTER_NAME' already exists, using it"
  else
    log "Create Kind cluster '$CLUSTER_NAME'"
    kind create cluster --name "$CLUSTER_NAME" --config "$KIND_DIR/configs/kind-config.yml"
  fi
  install_ingress
}

build () {
  log "Build images"
  # buildx refuses a build context outside the compose file directory (e.g. '..')
  # unless it is allowed: the project is the one place the images may read from.
  local allow=()
  if docker buildx bake --help 2>&1 | grep -q -- '--allow'; then
    allow=(--allow "fs.read=$PROJECT_ROOT")
  fi
  (cd "$(dirname "$COMPOSE_FILE")" && docker buildx bake ${allow[@]+"${allow[@]}"} --file "$(basename "$COMPOSE_FILE")" --load)
}

load () {
  log "Load images into cluster '$CLUSTER_NAME'"
  local images
  images="$(docker run -i --rm mikefarah/yq -o t '.services | map(select(.build) | .image)' < "$COMPOSE_FILE")"
  if [ -z "$images" ]; then
    warn "No service with a 'build' section in $COMPOSE_FILE, nothing to load."
    return 0
  fi
  # One image name per word
  # shellcheck disable=SC2086
  kind load docker-image --name "$CLUSTER_NAME" $images
}

deploy () {
  run_hook deploy "$MODE"
}

clean () {
  run_hook clean
}

delete () {
  log "Delete Kind cluster '$CLUSTER_NAME'"
  kind delete cluster --name "$CLUSTER_NAME"
}

# Parse options and commands, in any order: './run.sh dev -t v1' or './run.sh -t v1 dev'
while [ $# -gt 0 ]; do
  case "$1" in
    -*)
      OPTIND=1
      while getopts hc:d:f:n:t:y flag; do
        case "${flag}" in
          c)
            COMMANDS="${COMMANDS:+$COMMANDS }${OPTARG}";;
          d)
            DOMAINS="${OPTARG}";;
          f)
            COMPOSE_FILE="$(abs_path "${OPTARG}")";;
          n)
            CLUSTER_NAME="${OPTARG}";;
          t)
            TAG="${OPTARG}";;
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
      # A lone '-' is not an option and not a command either
      [ "$OPTIND" -gt 1 ] || die "Unexpected argument: '$1'."
      shift $((OPTIND - 1));;
    *)
      COMMANDS="${COMMANDS:+$COMMANDS }$1"
      shift;;
  esac
done
COMMANDS="$(printf '%s' "$COMMANDS" | tr ',' ' ')"
KUBE_CONTEXT="kind-$CLUSTER_NAME"

# Options validation
if [ -z "$COMMANDS" ]; then
  warn "Missing command."
  print_help >&2
  exit 1
fi

MODE="dev"
MODE_SET=""
DO_BUILD="false"
DO_CLEAN="false"
DO_CREATE="false"
DO_DELETE="false"
DO_DEPLOY="false"
DO_LOAD="false"
for CMD in $COMMANDS; do
  case " $KNOWN_COMMANDS " in
    *" $CMD "*) ;;
    *)
      warn "Unknown command '$CMD'."
      print_help >&2
      exit 1;;
  esac
  case "$CMD" in
    create) DO_CREATE="true";;
    build) DO_BUILD="true"; DO_LOAD="true";;
    load) DO_LOAD="true";;
    deploy) DO_DEPLOY="true";;
    clean) DO_CLEAN="true";;
    delete) DO_DELETE="true";;
    dev | prod)
      [ -z "$MODE_SET" ] || [ "$MODE_SET" = "$CMD" ] || die "'dev' and 'prod' cannot be combined."
      MODE_SET="$CMD"
      MODE="$CMD"
      DO_CREATE="true"; DO_BUILD="true"; DO_LOAD="true"; DO_DEPLOY="true";;
  esac
done

# Domains end up in /etc/hosts: only accept plain host names.
DOMAIN_LIST="$(printf '%s' "$DOMAINS" | tr ',' ' ')"
for DOMAIN in $DOMAIN_LIST; do
  if ! printf '%s' "$DOMAIN" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'; then
    die "Invalid domain '$DOMAIN'."
  fi
done

if [ "$DO_BUILD" = "true" ] || [ "$DO_LOAD" = "true" ]; then
  [ -f "$COMPOSE_FILE" ] || die "Docker compose file '$COMPOSE_FILE' does not exist (use -f to point to another one)."
  if grep -Eq '<[a-z_]+>' "$COMPOSE_FILE"; then
    die "'$COMPOSE_FILE' still holds the template placeholders: declare your images in it first."
  fi
fi

# Prerequisites
docker info > /dev/null 2>&1 || die "Docker is not running: start Docker Desktop (or your container engine) and try again."
if [ "$DO_CREATE" = "true" ] || [ "$DO_LOAD" = "true" ] || [ "$DO_DELETE" = "true" ]; then
  ensure_kind
fi
if [ "$DO_CREATE" = "true" ]; then
  need helm "brew install helm"
fi
if [ "$DO_BUILD" = "true" ]; then
  docker buildx version > /dev/null 2>&1 || die "docker buildx is required to build the images."
fi

# Every command runs from the project root (the directory mounted in the node)
cd "$PROJECT_ROOT"

log "$(docker --version) | cluster: $CLUSTER_NAME | project: $PROJECT_ROOT"


# Add local services to /etc/hosts
if [ -n "$DOMAIN_LIST" ]; then
  log "Add services local domains to /etc/hosts"
  MISSING_DOMAINS=""
  for DOMAIN in $DOMAIN_LIST; do
    # Whole-name match on non-comment lines only
    if ! awk -v d="$DOMAIN" '!/^[ \t]*#/ { for (i = 2; i <= NF; i++) if ($i == d) found = 1 } END { exit !found }' /etc/hosts; then
      MISSING_DOMAINS="${MISSING_DOMAINS:+$MISSING_DOMAINS }$DOMAIN"
    fi
  done
  if [ -z "$MISSING_DOMAINS" ]; then
    echo "Already there."
  else
    printf '\n# Kind\n127.0.0.1  %s\n' "$MISSING_DOMAINS" | sudo tee -a /etc/hosts > /dev/null
    echo "Added: $MISSING_DOMAINS"
  fi
fi


# The cluster boots while the images build: both are needed before the images get loaded
PID_CREATE=""
PID_BUILD=""
if [ "$DO_CREATE" = "true" ]; then
  create &
  PID_CREATE="$!"
fi
if [ "$DO_BUILD" = "true" ]; then
  build &
  PID_BUILD="$!"
fi
STATUS=0
for PID in $PID_CREATE $PID_BUILD; do
  wait "$PID" || STATUS=$?
done
[ "$STATUS" -eq 0 ] || die "Cluster creation or image build failed."

if [ "$DO_LOAD" = "true" ]; then
  load
fi

if [ "$DO_DEPLOY" = "true" ]; then
  deploy
fi

if [ "$DO_CLEAN" = "true" ]; then
  clean
fi

if [ "$DO_DELETE" = "true" ]; then
  delete
fi

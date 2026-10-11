#!/bin/bash

set -euo pipefail

# Colors
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_OFF='\033[0m'

# Versions
KIND_VERSION="0.33.0"
# ingress-nginx was retired in March 2026 and gets no more releases: it stays
# pinned to its last one, traefik is the default controller.
INGRESS_NGINX_VERSION="1.15.1"

# Defaults
SCRIPT_PATH="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"
INGRESS_CONTROLLER="traefik"
COMPOSE_FILE="$SCRIPT_PATH/docker-compose.yml"
COMMAND=""
DOMAINS=""
TAG=""
KNOWN_COMMANDS="create clean delete build load deploy dev prod"

# Script helper
TEXT_HELPER="\nThis script aims to manage a local kubernetes cluster using Kind also known as Kubernetes in Docker.
Following flags are available:

  -c    Command to run. Multiple commands can be provided as a comma separated list.
        Available commands are :
          create  - Create kind cluster.
          clean   - Delete images in kind cluster (keep only infra resources and ingress controller).
          delete  - Delete kind cluster.
          build   - Build and load docker images from compose file into cluster nodes.
          load    - Load docker images from compose file into cluster nodes.
          deploy  - Deploy the application (fill in the 'deploy' function).
          dev     - Run application in development mode.
          prod    - Run application in production mode.

  -d    Domains to add in /etc/hosts for local services resolution.
        Comma separated list, this will require sudo.

  -f    Path to the docker-compose file that will be used with Kind (default to '$COMPOSE_FILE').

  -i    Ingress controller to install (available values are 'traefik' or 'nginx', default to '$INGRESS_CONTROLLER').
        ingress-nginx is retired upstream and pinned to its last release ($INGRESS_NGINX_VERSION).

  -t    Tag used to deploy application images.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:i:t: flag; do
  case "${flag}" in
    c)
      COMMAND=${OPTARG};;
    d)
      DOMAINS=${OPTARG};;
    f)
      COMPOSE_FILE=${OPTARG};;
    i)
      INGRESS_CONTROLLER=${OPTARG};;
    t)
      TAG=${OPTARG};;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done


# Functions
# True when the comma separated command list contains the given command.
has_command() {
  case ",$COMMAND," in
    *",$1,"*) return 0;;
    *) return 1;;
  esac
}

sha256() {
  if command -v sha256sum > /dev/null 2>&1; then
    sha256sum "$1" | cut -d ' ' -f 1
  else
    shasum -a 256 "$1" | cut -d ' ' -f 1
  fi
}

install_kind() {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Install kind...\n\n"
  if [ "$(uname)" = "Linux" ]; then
    OS="linux"
  elif [ "$(uname)" = "Darwin" ]; then
    OS="darwin"
  else
    printf "\n\nNo installation available for your system, please refer to the installation guide\n\n" >&2
    exit 1
  fi

  if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="amd64"
  elif [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
    ARCH="arm64"
  else
    printf "\n\nNo kind binary for architecture '%s', please refer to the installation guide\n\n" "$(uname -m)" >&2
    exit 1
  fi

  # Download and check the binary before anything gets installed
  local download_dir
  local base_url="https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-${OS}-${ARCH}"
  download_dir="$(mktemp -d "${TMPDIR:-/tmp}/kind-install.XXXXXX")"
  curl -fsSL -o "$download_dir/kind" "$base_url"
  curl -fsSL -o "$download_dir/kind.sha256sum" "$base_url.sha256sum"
  if [ "$(sha256 "$download_dir/kind")" != "$(cut -d ' ' -f 1 "$download_dir/kind.sha256sum")" ]; then
    rm -rf "$download_dir"
    printf "\n\n${COLOR_RED}Error.${COLOR_OFF} Checksum mismatch for kind v%s, nothing was installed.\n\n" "$KIND_VERSION" >&2
    exit 1
  fi
  sudo install -d /usr/local/bin
  sudo install -m 0755 "$download_dir/kind" /usr/local/bin/kind
  rm -rf "$download_dir"

  printf "\n\n%s installed\n\n" "$(kind --version)"
}

create () {
  if ! kind get clusters 2> /dev/null | grep -qx 'kind'; then
    printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Create Kind cluster\n\n"
    kind create cluster --config "$SCRIPT_PATH/configs/kind-config.yml"
    if [ "$INGRESS_CONTROLLER" = "nginx" ]; then
      printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Install Nginx ingress controller\n\n"
      printf "${COLOR_YELLOW}Warning.${COLOR_OFF} ingress-nginx is retired upstream and receives no security fixes, prefer '-i traefik'.\n" >&2
      kubectl --context kind-kind apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v${INGRESS_NGINX_VERSION}/deploy/static/provider/kind/deploy.yaml"
      # The cluster maps host ports 80/443 to node ports 30080/30443 (configs/kind-config.yml).
      kubectl --context kind-kind patch service ingress-nginx-controller --namespace ingress-nginx --type json \
        -p '[{"op":"add","path":"/spec/ports/0/nodePort","value":30080},{"op":"add","path":"/spec/ports/1/nodePort","value":30443}]'
      sleep 20
      kubectl --context kind-kind wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    elif [ "$INGRESS_CONTROLLER" = "traefik" ]; then
      printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Install traefik ingress controller\n\n"
      helm repo add traefik https://traefik.github.io/charts --force-update
      helm repo update traefik
      helm --kube-context kind-kind upgrade \
        --install \
        --wait \
        --namespace ingress-traefik \
        --create-namespace \
        --values "$SCRIPT_PATH/configs/traefik-values.yml" \
        traefik traefik/traefik
    fi
  fi
}

build () {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Build images into cluster node\n\n"
  (cd "$(dirname "$COMPOSE_FILE")" && docker buildx bake --file "$(basename "$COMPOSE_FILE")" --load)
}

load () {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Load images into cluster node\n\n"
  local images
  images="$(docker run -i --rm mikefarah/yq -o t '.services | map(select(.build) | .image)' < "$COMPOSE_FILE")"
  # One image name per word
  # shellcheck disable=SC2086
  kind load docker-image $images
}

# $1: 'dev' or 'prod' (see env/helm-values.<mode>.yaml), TAG: image tag given with -t.
deploy () {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Deploy application in %s mode (tag: %s)\n\n" "$1" "${TAG:-none}"
  # Insert the commands to install your application here !
}

clean () {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Clean Kind cluster\n\n"
  # Insert the commands to uninstall your application here !
}

delete () {
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Delete Kind cluster\n\n"
  kind delete cluster
}

# Waits for the background job whose id is held by the variable named \$1, once:
# the variable is emptied so the job is never waited for twice.
wait_job() {
  local pid="${!1}"
  if [ -n "$pid" ]; then
    printf -v "$1" '%s' ''
    wait "$pid"
  fi
}


# Options validation
for CMD in $(printf '%s' "$COMMAND" | tr ',' ' '); do
  case " $KNOWN_COMMANDS " in
    *" $CMD "*) ;;
    *)
      printf "\nUnknown command '%s'.\n" "$CMD" >&2
      print_help >&2
      exit 1;;
  esac
done

if [ "$INGRESS_CONTROLLER" != "traefik" ] && [ "$INGRESS_CONTROLLER" != "nginx" ]; then
  printf "\nUnknown ingress controller '%s' (expected 'traefik' or 'nginx').\n" "$INGRESS_CONTROLLER" >&2
  exit 1
fi

# Domains end up in /etc/hosts: only accept plain host names.
DOMAIN_LIST="$(printf '%s' "$DOMAINS" | tr ',' ' ')"
for DOMAIN in $DOMAIN_LIST; do
  if ! printf '%s' "$DOMAIN" | grep -Eq '^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$'; then
    printf "\nInvalid domain '%s'.\n" "$DOMAIN" >&2
    exit 1
  fi
done

if (has_command build || has_command load || has_command dev || has_command prod) && [ ! -f "$COMPOSE_FILE" ]; then
  printf "\nDocker compose file %s does not exist.\n" "$COMPOSE_FILE" >&2
  print_help >&2
  exit 1
fi


# Script condition
if ! command -v kind > /dev/null 2>&1; then
  while true; do
    read -r -p "You need kind to run this script. Do you wish to install kind? [y/n] " yn
    case $yn in
      [Yy]*)
        install_kind
        break;;
      [Nn]*)
        exit 1;;
      *)
        echo "Please answer yes or no.";;
    esac
  done
fi

printf "\n${COLOR_RED}[kind wrapper].${COLOR_OFF} %s, %s\n" "$(docker --version)" "$(kind --version)"


# Add local services to /etc/hosts
if [ -n "$DOMAIN_LIST" ]; then
  printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Add services local domains to /etc/hosts\n\n"
  MISSING_DOMAINS=""
  for DOMAIN in $DOMAIN_LIST; do
    # Whole-name match on non-comment lines only
    if ! awk -v d="$DOMAIN" '!/^[[:space:]]*#/ { for (i = 2; i <= NF; i++) if ($i == d) found = 1 } END { exit !found }' /etc/hosts; then
      MISSING_DOMAINS="${MISSING_DOMAINS:+$MISSING_DOMAINS }$DOMAIN"
    fi
  done
  if [ -z "$MISSING_DOMAINS" ]; then
    printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Services local domains already added to /etc/hosts\n\n"
  else
    printf '\n# Kind\n127.0.0.1  %s\n' "$MISSING_DOMAINS" | sudo tee -a /etc/hosts > /dev/null
    printf "\n\n${COLOR_RED}[kind wrapper].${COLOR_OFF} Services local domains successfully added to /etc/hosts\n\n"
  fi
fi


JOB_ID_CREATE=""
JOB_ID_BUILD=""
JOB_ID_LOAD=""

# Deploy cluster with the ingress controller
if has_command create; then
  create &
  JOB_ID_CREATE="$!"
fi


# Build and load images into cluster nodes
if has_command build; then
  build &
  JOB_ID_BUILD="$!"
  wait_job JOB_ID_CREATE
  wait_job JOB_ID_BUILD
  load &
  JOB_ID_LOAD="$!"
fi


# Load images into cluster nodes (already done by 'build')
if has_command load && ! has_command build; then
  wait_job JOB_ID_CREATE
  load &
  JOB_ID_LOAD="$!"
fi


# Deploy application
if has_command deploy; then
  wait_job JOB_ID_CREATE
  wait_job JOB_ID_BUILD
  wait_job JOB_ID_LOAD
  deploy dev
fi


# Clean cluster application resources
if has_command clean; then
  clean
fi


# Delete cluster
if has_command delete; then
  delete
fi


# Deploy application in dev or prod mode
# shellcheck disable=SC2034 # the job ids are read by wait_job through indirect expansion
for MODE in dev prod; do
  has_command "$MODE" || continue
  wait_job JOB_ID_CREATE
  wait_job JOB_ID_BUILD
  wait_job JOB_ID_LOAD
  create &
  JOB_ID_CREATE="$!"
  build &
  JOB_ID_BUILD="$!"
  wait_job JOB_ID_CREATE
  wait_job JOB_ID_BUILD
  load &
  JOB_ID_LOAD="$!"
  wait_job JOB_ID_LOAD
  deploy "$MODE"
done

# Surface failures of jobs nobody waited for
wait_job JOB_ID_CREATE
wait_job JOB_ID_BUILD
wait_job JOB_ID_LOAD

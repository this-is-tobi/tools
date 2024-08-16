#!/bin/bash

set -e
set -o pipefail

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Get versions
DOCKER_VERSION="$(docker --version)"

# Default
PROJECT_DIR="$(git rev-parse --show-toplevel)"
SCRIPT_PATH="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
INGRESS_CONTROLLER="nginx"
COMPOSE_FILE="$SCRIPT_PATH/docker-compose.yml"

# Declare script helper
TEXT_HELPER="\nThis script aims to manage a local kubernetes cluster using Kind also known as Kubernetes in Docker.
Following flags are available:

  -c    Command tu run. Multiple commands can be provided as a comma separated list.
        Available commands are :
          create  - Create kind cluster.
          clean   - Delete images in kind cluster (keep only infra resources and ingress controller).
          delete  - Delete kind cluster.
          build   - Build and load docker images from compose file into cluster nodes.
          load    - Load docker images from compose file into cluster nodes.
          dev     - Run application in development mode.
          prod    - Run application in production mode.

  -d    Domains to add in /etc/hosts for local services resolution. 
        Comma separated list, this will require sudo.

  -f    Path to the docker-compose file that will be used with Kind (default to '$COMPOSE_FILE').

  -i    Ingress controller to install (available values are 'nginx' or 'traefik', default to '$INGRESS_CONTROLLER').

  -t    Tag used to deploy application images. 
        If the 'CI' environment variable is set to 'true', it will use the 
        '$PROJECT_DIR/$HELM_DIR/values.yaml' images instead of local ones.

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
    h | *)
      print_help
      exit 0;;
  esac
done


# Functions
install_kind() {
  printf "\n\n${red}[kind wrapper].${no_color} Install kind...\n\n"
  if [ "$(uname)" = "Linux" ]; then
    OS="linux"
  elif [ "$(uname)" = "Darwin" ]; then
    OS="darwin"
  else
    printf "\n\nNo installation available for your system, plese refer to the installation guide\n\n"
    exit 0
  fi

  if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="amd64"
  elif [ "$(uname -m)" = "arm64" ] || [ "$(uname -m)" = "aarch64" ]; then
    ARCH="arm64"
  fi

  KIND_VERSION="0.23.0"
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${VERSION}/kind-${OS}-${ARCH}"
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind

  printf "\n\n$(kind --version) installed\n\n"
}

create () {
  if [ -z "$(kind get clusters | grep 'kind')" ]; then
    printf "\n\n${red}[kind wrapper].${no_color} Create Kind cluster\n\n"
    kind create cluster --config $SCRIPT_PATH/configs/kind-config.yml
    if [ "$INGRESS_CONTROLLER" = "nginx" ]; then
      printf "\n\n${red}[kind wrapper].${no_color} Install Nginx ingress controller\n\n"
      kubectl --context kind-kind apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
      sleep 20
      kubectl --context kind-kind wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=90s
    elif [ "$INGRESS_CONTROLLER" = "traefik" ]; then
      printf "\n\n${red}[kind wrapper].${no_color} Install traefik ingress controller\n\n"
      helm --kube-context kind-kind repo add traefik https://traefik.github.io/charts && helm repo update
      helm --kube-context kind-kind upgrade \
        --install \
        --wait \
        --namespace ingress-traefik \
        --create-namespace \
        --values $SCRIPTPATH/configs/traefik-values.yml \
        traefik traefik/traefik
    fi
  fi
}

build () {
  printf "\n\n${red}[kind wrapper].${no_color} Build images into cluster node\n\n"
  cd $(dirname "$COMPOSE_FILE") && docker buildx bake --file $(basename "$COMPOSE_FILE") --load && cd -
}

load () {
  printf "\n\n${red}[kind wrapper].${no_color} Load images into cluster node\n\n"
  kind load docker-image $(cat "$COMPOSE_FILE" | docker run -i --rm mikefarah/yq -o t '.services | map(select(.build) | .image)')
}

deploy () {
  printf "\n\n${red}[kind wrapper].${no_color} Deploy application in development mode\n\n"
  # Insert the commands to install your application here !
}

clean () {
  printf "\n\n${red}[kind wrapper].${no_color} Clean Kind cluster\n\n"
  # Insert the commands to uninstall your application here !
}

delete () {
  printf "\n\n${red}[kind wrapper].${no_color} Delete Kind cluster\n\n"
  kind delete cluster
}


# Script condition
if [ -z "$(kind --version)" ]; then
  while true; do
    read -p "\nYou need kind to run this script. Do you wish to install kind?\n" yn
    case $yn in
      [Yy]*)
        install_kind;;
      [Nn]*)
        exit 1;;
      *)
        echo "\nPlease answer yes or no.\n";;
    esac
  done
fi

if [[ "$COMMAND" =~ "build" ]] || [[ "$COMMAND" =~ "load" ]] && [ ! -f "$(readlink -f $COMPOSE_FILE)" ]; then
  echo "\nDocker compose file $COMPOSE_FILE does not exist.\n"
  print_help
  exit 1
fi


# Add local services to /etc/hosts
if [ ! -z "$DOMAINS" ]; then
  printf "\n\n${red}[kind wrapper].${no_color} Add services local domains to /etc/hosts\n\n"
  FORMATED_DOMAINS="$(echo "$DOMAINS" | sed 's/,/\ /g')"
  if [ "$(grep -c "$FORMATED_DOMAINS" /etc/hosts)" -ge 1 ]; then
    printf "\n\n${red}[kind wrapper].${no_color} Services local domains already added to /etc/hosts\n\n"
  else
    sudo sh -c "echo $'\n\n# Kind\n127.0.0.1  $FORMATED_DOMAINS' >> /etc/hosts"
    printf "\n\n${red}[kind wrapper].${no_color} Services local domains successfully added to /etc/hosts\n\n"
  fi
fi


# Deploy cluster with trefik ingress controller
if [[ "$COMMAND" =~ "create" ]]; then
  create &
  JOB_ID_CREATE="$!"
fi


# Build and load images into cluster nodes
if [[ "$COMMAND" =~ "build" ]]; then
  build &
  JOB_ID_BUILD="$!"
  [ ! -z $JOB_ID_CREATE ] && wait $JOB_ID_CREATE
  wait $JOB_ID_BUILD
  load &
  JOB_ID_LOAD="$!"
fi


# Load images into cluster nodes
if [[ "$COMMAND" =~ "load" ]]; then
  [ ! -z $JOB_ID_CREATE ] && wait $JOB_ID_CREATE
  load &
  JOB_ID_LOAD="$!"
fi


# Deploy application in dev or test mode
if [[ "$COMMAND" =~ "deploy" ]]; then
  [ ! -z $JOB_ID_CREATE ] && wait $JOB_ID_CREATE
  [ ! -z $JOB_ID_BUILD ] && wait $JOB_ID_BUILD
  [ ! -z $JOB_ID_LOAD ] && wait $JOB_ID_LOAD
  deploy
fi


# Clean cluster application resources
if [ "$COMMAND" = "clean" ]; then
  clean
fi


# Delete cluster
if [ "$COMMAND" = "delete" ]; then
  delete
fi


# Deploy application in dev or test mode
if [[ "$COMMAND" =~ "dev" ]]; then
  create &
  JOB_ID_CREATE="$!"
  build &
  JOB_ID_BUILD="$!"
  wait $JOB_ID_CREATE
  wait $JOB_ID_BUILD
  load &
  JOB_ID_LOAD="$!"
  wait $JOB_ID_LOAD
  deploy
fi

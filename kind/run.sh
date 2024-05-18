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
HELM_RELEASE_NAME="template"
HELM_DIR="./helm"
HELM_ARGS=""
CI_ARGS=""


# Declare script helper
TEXT_HELPER="\nThis script aims to manage a local kubernetes cluster using Kind also known as Kubernetes in Docker.
Following flags are available:

  -c    Command tu run. Multiple commands can be provided as a comma separated list.
        Available commands are :
          create  - Create kind cluster.
          clean   - Delete images in kind cluster (keep only infra resources and ingress controller).
          delete  - Delete kind cluster.
          build   - Build, push and load docker images from compose file into cluster nodes.
          load    - Load docker images from compose file into cluster nodes.
          dev     - Run application in development mode.
          prod    - Run application in production mode.

  -d    Domains to add in /etc/hosts for local services resolution. 
        Comma separated list, this will require sudo.

  -f    Path to the docker-compose file that will be used with Kind.

  -i    Install kind.

  -t    Tag used to deploy application images. 
        If the 'CI' environment variable is set to 'true', it will use the 
        '$PROJECT_DIR/$HELM_DIR/values.yaml' images instead of local ones.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:ik:t: flag; do
  case "${flag}" in
    c)
      COMMAND=${OPTARG};;
    d)
      DOMAINS=${OPTARG};;
    f)
      COMPOSE_FILE=${OPTARG};;
    i)
      INSTALL_KIND=true;;
    k)
      KUBECONFIG_PATH=${OPTARG};;
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

  KIND_VERSION="0.22.0"
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v${VERSION}/kind-${OS}-${ARCH}"
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind

  printf "\n\n$(kind --version) installed\n\n"
}

create_cluster () {
  if [[ "$COMMAND" =~ "create" ]]; then
    if [ -z "$(kind get clusters | grep 'kind')" ]; then
      printf "\n\n${red}[kind wrapper].${no_color} Create Kind cluster\n\n"

      kind create cluster --config $SCRIPT_PATH/configs/kind-config.yml

      printf "\n\n${red}[kind wrapper].${no_color} Install Traefik ingress controller\n\n"

      helm --kube-context kind-kind repo add traefik https://traefik.github.io/charts && helm repo update
      helm --kube-context kind-kind upgrade \
        --install \
        --wait \
        --namespace traefik \
        --create-namespace \
        --values $SCRIPT_PATH/configs/traefik-values.yml \
        traefik traefik/traefik
    fi
  fi
}

build () {
  printf "\n\n${red}[kind wrapper].${no_color} Build images into cluster node\n\n"

  cd $(dirname "$COMPOSE_FILE") \
    && docker buildx bake --file $(basename "$COMPOSE_FILE") --load \
    && cd -
}

load () {
  printf "\n\n${red}[kind wrapper].${no_color} Load images into cluster node\n\n"

  kind load docker-image $(cat "$COMPOSE_FILE" \
    | docker run -i --rm mikefarah/yq -o t '.services | map(select(.build) | .image)')
}

clean () {
  printf "\n\n${red}[kind wrapper].${no_color} Clean cluster resources\n\n"

  helm --kube-context kind-kind uninstall $HELM_RELEASE_NAME
}

delete () {
  printf "\n\n${red}[kind wrapper].${no_color} Delete Kind cluster\n\n"

  kind delete cluster
}

dev () {
  printf "\n\n${red}[kind wrapper].${no_color} Deploy application in development mode\n\n"

  helm dependency build $HELM_DIR
  helm --kube-context kind-kind upgrade \
    --install \
    --wait \
    --values $SCRIPT_PATH/env/helm-values.dev.yaml \
    $HELM_RELEASE_NAME $HELM_DIR

  for i in $(kubectl --context kind-kind  get deploy -o name); do 
    kubectl --context kind-kind  rollout status $i -w --timeout=150s; 
  done
}

prod () {
  printf "\n\n${red}[kind wrapper].${no_color} Deploy application in production mode\n\n"

  if [ ! -z "$TAG" ]; then
    HELM_ARGS="--set api.image.tag=$TAG --set docs.image.tag=$TAG"
  fi
  if [ "$CI" = "true" ]; then
    API_IMAGE_REPO="$(yq '.api.image.repository' $PROJECT_DIR/$HELM_DIR/values.yaml)"
    DOCS_IMAGE_REPO="$(yq '.docs.image.repository' $PROJECT_DIR/$HELM_DIR/values.yaml)"
    CI_ARGS="--set api.image.repository=$API_IMAGE_REPO --set docs.image.repository=$DOCS_IMAGE_REPO"
  fi

  helm dependency build $HELM_DIR
  helm --kube-context kind-kind upgrade \
    --install \
    --wait \
    --values $SCRIPT_PATH/env/helm-values.prod.yaml \
    $HELM_ARGS \
    $HELM_RELEASE_NAME $HELM_DIR

  for i in $(kubectl --context kind-kind get deploy -o name); do 
    kubectl --context kind-kind  rollout status $i -w --timeout=150s
  done
}


# Script condition
if [ "$INSTALL_KIND" = "true" ] && [ -z "$(kind --version)" ]; then
  install_kind
fi

if [ -z "$(kind --version)" ]; then
  echo "\nYou need to install kind to run this script.\n"
  print_help
  exit 1
fi

if [[ "$COMMAND" =~ "build" ]] && [ ! -f "$(readlink -f $COMPOSE_FILE)" ]; then
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
  create_cluster &
  JOB_ID_CREATE="$!"
fi


# Build and load images into cluster nodes
if [[ "$COMMAND" =~ "build" ]]; then
  build &
  JOB_ID_BUILD="$!"
  wait $JOB_ID_CREATE
  wait $JOB_ID_BUILD
  load
fi


# Load images into cluster nodes
if [[ "$COMMAND" =~ "load" ]]; then
  wait $JOB_ID_CREATE
  load
fi


# Clean cluster application resources
if [ "$COMMAND" = "clean" ]; then
  clean
fi


# Deploy application in dev or test mode
if [[ "$COMMAND" =~ "dev" ]]; then
  wait $JOB_ID_CREATE
  dev
elif [[ "$COMMAND" =~ "prod" ]]; then
  wait $JOB_ID_CREATE
  prod
fi


# Delete cluster
if [ "$COMMAND" = "delete" ]; then
  delete
fi

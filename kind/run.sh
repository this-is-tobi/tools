#!/bin/bash

set -e

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'

# Console step increment
i=1

# Get versions
DOCKER_VERSION="$(docker --version)"
KIND_VERSION="$(kind --version)"

# Default
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"


# Declare script helper
TEXT_HELPER="\nThis script aims to manage a local kubernetes cluster using Kind also known as Kubernetes in Docker.
Following flags are available:

  -c    Command tu run. Multiple commands can be provided as a comma separated list.
        Available commands are :
          build   - Build and push to the local registry docker compose images.
          create  - Create local registry and kind cluster.
          delete  - Delete local registry and kind cluster.

  -d    Domains to add in /etc/hosts for local services resolution. Comma separated list. This will require sudo.

  -f    Path to the docker-compose file that will be used with Kind.

  -i    Install kind.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:i flag; do
  case "${flag}" in
    c)
      COMMAND=${OPTARG};;
    d)
      DOMAINS=${OPTARG};;
    f)
      COMPOSE_FILE=${OPTARG};;
    i)
      INSTALL_KIND=true;;
    h | *)
      print_help
      exit 0;;
  esac
done


# Utils
install_kind() {
  printf "\n\n${red}Optional.${no_color} Install kind...\n\n"
  if [ "$(uname)" = "Linux" ]; then
    OS=linux
  elif [ "$(uname)" = "Darwin" ]; then
    OS=darwin
  else
    printf "\n\nNo installation available for your system, plese refer to the installation guide\n\n"
    exit 0
  fi

  if [ "$(uname)" = "x86_64" ]; then
    ARCH=amd64
  elif [ "$(uname)" = "arm64" ] || [ "$(uname)" = "aarch64" ]; then
    ARCH=arm64
  fi

  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.20.0/kind-$OS-$ARCH"
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind

  printf "\n\nkind version $(kind --version) installed\n\n"
}

if [ "$INSTALL_KIND" = "true" ]; then
  install_kind
fi


# Script condition
if [ -z "$(kind --version)" ]; then
  while true; do
    read -p "\nYou need kind to run this script. Do you wish to install kind?\n" yn
    case $yn in
      [Yy]*)
        install_kind;;
      [Nn]*)
        exit 0;;
      *)
        echo "\nPlease answer yes or no.\n";;
    esac
  done
fi

if [[ "$COMMAND" =~ "build" ]] && [ ! -f "$(readlink -f $COMPOSE_FILE)" ]; then
  echo "\nDocker compose file $COMPOSE_FILE does not exist."
  print_help
  exit 1
fi


# Deploy cluster with trefik ingress controller
if [[ "$COMMAND" =~ "create" ]]; then
  if [ -z "$(kind get clusters | grep 'kind')" ]; then
    printf "\n\n${red}${i}.${no_color} Create Kind cluster\n\n"
    i=$(($i + 1))

    kind create cluster --config $SCRIPTPATH/configs/kind-config.yml


    printf "\n\n${red}${i}.${no_color} Install Traefik ingress controller\n\n"
    i=$(($i + 1))

    helm repo add traefik https://traefik.github.io/charts && helm repo update
    helm upgrade --install --namespace traefik --create-namespace --values $SCRIPTPATH/configs/traefik-values.yml traefik traefik/traefik
  fi
fi

# Build and load images into cluster nodes
if [[ "$COMMAND" =~ "build" ]]; then
  printf "\n\n${red}${i}.${no_color} Push images to cluster registry\n\n"

  docker compose --file $COMPOSE_FILE build
  kind load docker-image $(yq -o t '.services | map(select(.build) | .image)' ./docker-compose-prod.yml)
fi

# Add local services to /etc/hosts
if [ ! -z "$DOMAINS" ]; then
  printf "\n\n${red}${i}.${no_color} Add local services to /etc/hosts\n\n"
  i=$(($i + 1))

  FORMATED_DOMAINS=echo "$DOMAINS" | sed 's/,/\ /g'
  [ ! $(sudo grep -q "$FORMATED_DOMAINS" /etc/hosts) ] && sudo sh -c "echo $'\n# Kind\n127.0.0.1  $FORMATED_DOMAINS' >> /etc/hosts"
fi

# Delete cluster
if [ "$COMMAND" = "delete" ]; then
  printf "\n\n${red}${i}.${no_color} Delete Kind cluster\n\n"
  i=$(($i + 1))

  kind delete cluster
fi

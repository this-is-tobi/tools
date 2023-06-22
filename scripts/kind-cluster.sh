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

  -c    Command tu run. Available commands are 'create' ro 'delete'.

  -f    Path to the docker-compose file that will be used with Kind.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:f: flag; do
  case "${flag}" in
    c)
      COMMAND=${OPTARG};;
    f)
      COMPOSE_FILE=${OPTARG};;
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

if [ "$COMMAND" = "create" ] && [ ! -f "$(readlink -f $COMPOSE_FILE)" ]; then
  echo "\nDocker compose file $COMPOSE_FILE does not exist."
  print_help
  exit 1
fi


# Maage Kind cluster
if [ "$COMMAND" = "create" ]; then
  # Build compose file images
  printf "\n\n${red}${i}.${no_color} Build compose file images\n\n"
  i=$(($i + 1))
  docker compose -f "$COMPOSE_FILE" build --pull

  # Start cluster
  printf "\n\n${red}${i}.${no_color} Create Kind cluster\n\n"
  i=$(($i + 1))
  [ -z "$(kind get clusters | grep 'kind')" ] && kind create cluster

  # Install Traefik ingress controller
  printf "\n\n${red}${i}.${no_color} Install Traefik ingress controller\n\n"
  i=$(($i + 1))
  helm repo add traefik https://traefik.github.io/charts && helm repo update
  helm upgrade --install --namespace traefik --create-namespace traefik traefik/traefik

  # Load images into kind cluster
  printf "\n\n${red}${i}.${no_color} Load images into Kind cluster\n\n"
  i=$(($i + 1))
  IMAGES=($(sh $SCRIPTPATH/build-matrix.sh -f "$COMPOSE_FILE" -t ci -n dso-console | jq -r '[.[] | select(.build != false)] | map(.build.tags[0]) | .[]'))
  for i in ${IMAGES[*]}; do
    kind load docker-image $i
  done
fi

if [ "$COMMAND" = "delete" ]; then
  # Stop cluster
  printf "\n\n${red}${i}.${no_color} Delete Kind cluster\n\n"
  i=$(($i + 1))
  kind delete cluster
fi

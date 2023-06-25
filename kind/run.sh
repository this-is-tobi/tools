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
REGISTRY_NAME=kind-registry
REGISTRY_PORT=5001
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${REGISTRY_PORT}"
NAMESPACE=""
TAG=latest


# Declare script helper
TEXT_HELPER="\nThis script aims to manage a local kubernetes cluster using Kind also known as Kubernetes in Docker.
Following flags are available:

  -c    Command tu run. Available commands are 'create' ro 'delete'.

  -d    Domains to add in /etc/hosts for local services resolution. Comma separated list.

  -f    Path to the docker-compose file that will be used with Kind.

  -n    Custom namespace used to tag images.

  -t    Tag to apply when building images.

  -h    Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hc:d:f:n:t: flag; do
  case "${flag}" in
    c)
      COMMAND=${OPTARG};;
    d)
      DOMAINS=${OPTARG};;
    f)
      COMPOSE_FILE=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    t)
      TAG=${OPTARG};;
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
  # Create registry container unless it already exists
  if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
    printf "\n\n${red}${i}.${no_color} Create container registry\n\n"
    i=$(($i + 1))
    docker run \
      -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" --name "${REGISTRY_NAME}" -v $SCRIPTPATH/registry:/var/lib/registry \
      registry:2
  fi

  # Start cluster
  if [ -z "$(kind get clusters | grep 'kind')" ]; then
    printf "\n\n${red}${i}.${no_color} Create Kind cluster\n\n"
    i=$(($i + 1))
    kind create cluster --config $SCRIPTPATH/configs/cluster.yml

    # Add registry to nodes
    printf "\n\n${red}${i}.${no_color} Add registry to cluster nodes\n\n"
    i=$(($i + 1))
    for node in $(kind get nodes); do
      docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
      cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${REGISTRY_NAME}:5000"]
EOF
  done

    # Connect the registry to the cluster
    printf "\n\n${red}${i}.${no_color} Connect registry to the cluster\n\n"
    i=$(($i + 1))
    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}")" = 'null' ]; then
      docker network connect "kind" "${REGISTRY_NAME}"
    fi

    # Add registry documentation
    printf "\n\n${red}${i}.${no_color} Add registry doc\n\n"
    i=$(($i + 1))
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

    # Install Traefik ingress controller
    printf "\n\n${red}${i}.${no_color} Install Traefik ingress controller\n\n"
    i=$(($i + 1))
    helm repo add traefik https://traefik.github.io/charts && helm repo update
    helm upgrade --install --namespace traefik --create-namespace --values $SCRIPTPATH/configs/traefik-values.yml traefik traefik/traefik

    # Push images to cluster registry
    printf "\n\n${red}${i}.${no_color} Push images to cluster registry\n\n"
    i=$(($i + 1))
    if [ "$NAMESPACE" = "" ]; then
      IMAGES=($(sh $SCRIPTPATH/../scripts/compose-to-matrix.sh -f $COMPOSE_FILE -t $TAG -r localhost:5001 | jq -c '.[] | select(.build != false)'))
    else
      IMAGES=($(sh $SCRIPTPATH/../scripts/compose-to-matrix.sh -f $COMPOSE_FILE -t $TAG -n $NAMESPACE -r localhost:5001 | jq -c '.[] | select(.build != false)'))
    fi
    for image in ${IMAGES[*]}; do
      TAG="$(echo $image | jq -r '.build.tags[0]')"
      CONTEXT="$(echo $image | jq -r '.build.context')"
      DOCKERFILE="$(echo $image | jq -r '.build.dockerfile')"
      TARGET="$(echo $image | jq -r '.build.target')"
      if [ "$TARGET" = "null" ]; then
        docker build --file "$DOCKERFILE" --tag "$TAG" --push "$CONTEXT"
      else
        docker build --file "$DOCKERFILE" --tag "$TAG" --target "$TARGET" --push "$CONTEXT"
      fi
    done
  fi

  # Add local services to /etc/hosts
  if [ ! -z "$DOMAINS" ]; then
    printf "\n\n${red}${i}.${no_color} Add local services to /etc/hosts\n\n"
    i=$(($i + 1))
    FORMATED_DOMAINS=echo "$DOMAINS" | sed 's/,/\ /g'
    [ ! $(sudo grep -q "$FORMATED_DOMAINS" /etc/hosts) ] && sudo sh -c "echo $'\n# Kind\n127.0.0.1  $FORMATED_DOMAINS' >> /etc/hosts"
  fi
fi

if [ "$COMMAND" = "delete" ]; then
  # Stop cluster
  printf "\n\n${red}${i}.${no_color} Delete Kind cluster\n\n"
  i=$(($i + 1))
  kind delete cluster

  # Delete registry container
  printf "\n\n${red}${i}.${no_color} Delete cluster registry\n\n"
  i=$(($i + 1))
  if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" = 'true' ]; then
    docker stop "${REGISTRY_NAME}" && \
      docker rm "${REGISTRY_NAME}" -v
  fi
fi

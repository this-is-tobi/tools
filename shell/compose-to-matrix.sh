#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Versions
DOCKER_VERSION="$(docker --version)"

# Defaults
REGISTRY="docker.io"
TAGS="latest"
COMMIT_SHA="$(git rev-parse --short HEAD)"
PLATFORMS="linux/amd64"
CSV=false
RECURSIVE=false

unset MAJOR_VERSION
unset MINOR_VERSION
unset PATCH_VERSION

# Script helper
TEXT_HELPER="
This script aims to build matrix for Github CI/CD. It will parse the given docker-compose file and return a json object with images infos (name, tag, context, dockerfile and if it need to be build)

Available flags:
  -a    Create recursive tags, if it match 'x.x.x' it will create 'x.x' and 'x'.
  -c    Use csv list formated output for tags instead of json array.
  -f    Docker-compose file used to build matrix.
  -n    Namespace used to tag images. e.g 'username/reponame'.
  -p    Target platforms used to build matrix (List/CSV format. ex: 'linux/amd64,linux/arm64').
        Default: '$PLATFORMS'.
  -r    Registry host used to build matrix.
        Default: '$REGISTRY'.
  -t    Docker tag used to build matrix.
        Default: '$TAGS'.
  -h    Print script help.

Example:
  ./compose-to-matrix.sh \\
    -f './path/to/docker-compose.yml' \\
    -n 'this-is-tobi/tools' \\
    -r 'docker.io' \\
    -t '1.0.0,1.0,1,latest' \\
    -p 'linux/amd64,linux/arm64' \\
    -a \\
    -c
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hacf:n:p:r:t: flag; do
  case "${flag}" in
    a)
      RECURSIVE=true;;
    c)
      CSV=true;;
    f)
      COMPOSE_FILE=${OPTARG};;
    n)
      NAMESPACE=${OPTARG};;
    p)
      PLATFORMS=${OPTARG};;
    r)
      REGISTRY=${OPTARG};;
    t)
      TAGS=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done


# Options validation
if [ ! -f "$(readlink -f $COMPOSE_FILE)" ]; then
  echo "\nDocker compose file $COMPOSE_FILE does not exist."
  print_help
  exit 1
fi

# Init
if [ "$REGISTRY" ] && [[ "$REGISTRY" != */ ]]; then
  REGISTRY="$REGISTRY/"
fi

if [ "$NAMESPACE" ] && [[ "$NAMESPACE" != */ ]]; then
  NAMESPACE="$NAMESPACE/"
fi

# Settings
printf "
Settings:
  > DOCKER_VERSION: ${DOCKER_VERSION}
  > COMPOSE_FILE: ${COMPOSE_FILE}
  > REGISTRY: ${REGISTRY}
  > NAMESPACE: ${NAMESPACE}
  > TAGS: ${TAGS}
  > PLATFORMS: ${PLATFORMS}
  > RECURSIVE: ${RECURSIVE}
  > CSV: ${CSV}
"

# Build core matrix
MATRIX=$(cat "$COMPOSE_FILE" \
  | docker run -i --rm mikefarah/yq -o=json \
  | jq \
    --arg d "$(dirname $(readlink -f $COMPOSE_FILE))" \
    --arg p "$PLATFORMS" \
    --arg r "$REGISTRY" \
    --arg t "$TAGS" \
    '.services | to_entries | map({
      image: (.value.image),
      name: (.value.image | split(":")[0] | split("/")[-1]),
      defaultTag: (.value.image | split(":")[1]),
      build: (
        if .value.build then {
          context: ($d + "/" + .value.build.context),
          dockerfile: ($d + "/" + .value.build.context + "/" + .value.build.dockerfile),
          target: (.value.build.target),
          platforms: [],
          tags: []
        } 
        else 
          false 
        end)
      })')

# Add tags in matrix
if [ ! -z "$TAGS" ]; then
  for t in $(echo $TAGS | tr "," "\n"); do
    if [[ "$t" == *"."*"."* ]] && [[ "$RECURSIVE" == "true" ]]; then
      MAJOR_VERSION="$(echo $t | cut -d "." -f 1)"
      MINOR_VERSION="$(echo $t | cut -d "." -f 2)"
      PATCH_VERSION="$(echo $t | cut -d "." -f 3)"

      MATRIX=$(echo "$MATRIX" \
        | jq \
          --arg r "$REGISTRY" \
          --arg n "$NAMESPACE" \
          --arg major "$MAJOR_VERSION" \
          --arg minor "$MINOR_VERSION" \
          'map(. |
            if .build != false then 
              .build.tags += [
                ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":" + $major),
                ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":" + $major + "." + $minor)
              ]
            else
              .
            end
          )')
    fi

    MATRIX=$(echo "$MATRIX" \
      | jq \
        --arg t "$t" \
        --arg r "$REGISTRY" \
        --arg n "$NAMESPACE" \
        'map(. |
          if .build != false then
            .build.tags += [
              ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":" + $t)
            ]
          else
            .
          end
        )')
  done
else
  MATRIX=$(echo "$MATRIX" \
    | jq \
      --arg r "$REGISTRY" \
      --arg n "$NAMESPACE" \
      'map(. |
        if .build != false then
          if .defaultTag | test("^[0-9].[0-9].[0-9]") then
            .build.tags += [
              ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":" + (.defaultTag | split(".")[0])),
              ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":" + (.defaultTag | split(".")[0]) + "." + (.defaultTag | split(".")[1])),
              ($r + $n + .image),
              ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":latest")
            ]
          else
            .build.tags += [
              ($r + $n + .image),
              ($r + $n + (.image | split(":")[0] | split("/")[-1]) + ":latest")
            ]
          end
        else
          .
        end
      )')
fi

# Add platforms in matrix
for p in $(echo $PLATFORMS | tr "," "\n"); do
  MATRIX=$(echo "$MATRIX" \
    | jq \
      --arg p "$p" \
      'map(. |
        if .build != false then
          .build.platforms += [
            ($p)
          ]
        else
          .
        end
      )')
done

# Update image key with first tag
MATRIX=$(echo "$MATRIX" \
  | jq \
    --arg t "$TAGS" \
    'map(. |
      if .build != false then 
        .image = (.image | split(":")[0] | split("/")[-1] + ":" + ($t | split(",")[0]))
      else
        .
      end
    )')

# Convert tags & platforms from json array to csv list (use join instead of @csv to don't get unwanted quotes)
if [ "$CSV" == "true" ]; then
  MATRIX=$(echo "$MATRIX" \
    | jq -r \
      'map(. |
        if .build != false then 
          .build.tags = (.build.tags | join(",")) |
          .build.platforms = (.build.platforms | join(","))
        else
          .
        end
      )')
fi

echo "$MATRIX" | jq .

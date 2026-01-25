#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'

# Script helper
TEXT_HELPER="
This script aims to perform a EOL search for a given package.

Available flags:
  -b    Enable boolean mode to print 'true' when the package version is the LTS version, otherwise print 'false'.
  -p    Package name to perform EOL search.
  -s    Enable search mode to find a package.
  -v    Package version (cycle) to perform EOL search.
  -h    Print script help.

Example:
  ./eol-infos.sh \\
    -p 'nodejs' \\
    -v '18' \\
    -b
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

check_status() {
  if [ "$(curl -o /dev/null -sL -w "%{http_code}" "https://endoflife.date/api/$PACKAGE_NAME.json")" -eq 404 ]; then
    echo "Package $PACKAGE_NAME not found.\n"
    exit 1
  fi
}

# Parse options
while getopts hbp:sv: flag; do
  case "${flag}" in
    b)
      BOOLEAN_MODE="true";;
    p)
      PACKAGE_NAME=${OPTARG};;
    s)
      SEARCH_MODE="true";;
    v)
      PACKAGE_VERSION=${OPTARG};;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > PACKAGE_NAME: ${PACKAGE_NAME}
  > PACKAGE_VERSION: ${PACKAGE_VERSION}
  > BOOLEAN_MODE: ${BOOLEAN_MODE}
  > SEARCH_MODE: ${SEARCH_MODE}
"

if [ "$SEARCH_MODE" = "true" ]; then
  EOL_INFOS=$(curl -sL --request GET \
    --url https://endoflife.date/api/all.json \
    --header 'Accept: application/json')

  printf "End of life search results for package: ${COLOR_BLUE}$PACKAGE_NAME${COLOR_OFF}\n\n"

  for PKG in $(echo $EOL_INFOS | jq -r --arg p "$PACKAGE_NAME" '.[] | select(test($p; "i"))'); do
    printf "$PKG\n" | sed 's/^/  /'
  done
elif [ -n "$PACKAGE_VERSION" ]; then
  check_status
  EOL_INFOS=$(curl -sL --request GET \
    --url https://endoflife.date/api/$PACKAGE_NAME/$PACKAGE_VERSION.json \
    --header 'Accept: application/json')

  if [ "$BOOLEAN_MODE" = "true" ]; then
    [[ $(echo $EOL_INFOS | jq -r '.support') > $(date '+%Y-%m-%d') ]] && echo "true" || echo "false"
  else
  printf "End of life infos for package: ${COLOR_BLUE}$PACKAGE_NAME (v$PACKAGE_VERSION)${COLOR_OFF} - https://endoflife.date/$PACKAGE_NAME\n
  Latest version: $(echo $EOL_INFOS | jq -r '.latest') ($(echo $EOL_INFOS | jq -r '.latestReleaseDate'))
  Release date: $(if ! [[ "$(echo $EOL_INFOS | jq -r '.releaseDate | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    else
      echo "$(echo $EOL_INFOS | jq -r '.releaseDate')";
    fi)
  Start of LTS: $(if ! [[ "$(echo $EOL_INFOS | jq -r '.lts | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    else
      echo "$(echo $EOL_INFOS | jq -r '.lts')";
    fi)
  End of LTS: $(if ! [[ "$(echo $EOL_INFOS | jq -r '.support | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    elif [[ $(echo $EOL_INFOS | jq -r '.support') > $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_GREEN}$(echo $EOL_INFOS | jq -r '.support')${COLOR_OFF}";
    elif [[ $(echo $EOL_INFOS | jq -r '.support') < $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_RED}$(echo $EOL_INFOS | jq -r '.support')${COLOR_OFF}";
    fi)
  EOL: $(if ! [[ "$(echo $EOL_INFOS | jq -r '.eol | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    elif [[ $(echo $EOL_INFOS | jq -r '.eol') > $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_GREEN}$(echo $EOL_INFOS | jq -r '.eol')${COLOR_OFF}";
    elif [[ $(echo $EOL_INFOS | jq -r '.eol') < $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_RED}$(echo $EOL_INFOS | jq -r '.eol')${COLOR_OFF}";
    fi)\n"
  fi
else
  check_status
  EOL_INFOS=$(curl -sL --request GET \
    --url https://endoflife.date/api/$PACKAGE_NAME.json \
    --header 'Accept: application/json')
  
  printf "End of life infos for package: ${COLOR_BLUE}$PACKAGE_NAME${COLOR_OFF} - https://endoflife.date/$PACKAGE_NAME\n"

  for EOL_CYCLE in $(echo "$EOL_INFOS" | jq -c '. | reverse | .[]'); do
  printf "
  Latest version: $(echo $EOL_CYCLE | jq -r '.latest') ($(echo $EOL_CYCLE | jq -r '.latestReleaseDate'))
  Release date: $(if ! [[ "$(echo $EOL_CYCLE | jq -r '.releaseDate | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    else
      echo "$(echo $EOL_CYCLE | jq -r '.releaseDate')";
    fi)
  Start of LTS: $(if ! [[ "$(echo $EOL_CYCLE | jq -r '.lts | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    else
      echo "$(echo $EOL_CYCLE | jq -r '.lts')";
    fi)
  End of LTS: $(if ! [[ "$(echo $EOL_CYCLE | jq -r '.support | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    elif [[ $(echo $EOL_CYCLE | jq -r '.support') > $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_GREEN}$(echo $EOL_CYCLE | jq -r '.support')${COLOR_OFF}";
    elif [[ $(echo $EOL_CYCLE | jq -r '.support') < $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_RED}$(echo $EOL_CYCLE | jq -r '.support')${COLOR_OFF}";
    fi)
  EOL: $(if ! [[ "$(echo $EOL_CYCLE | jq -r '.eol | select (.!=null)')" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then 
      echo "-";
    elif [[ $(echo $EOL_CYCLE | jq -r '.eol') > $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_GREEN}$(echo $EOL_CYCLE | jq -r '.eol')${COLOR_OFF}";
    elif [[ $(echo $EOL_CYCLE | jq -r '.eol') < $(date '+%Y-%m-%d') ]]; then 
      echo "${COLOR_RED}$(echo $EOL_CYCLE | jq -r '.eol')${COLOR_OFF}";
    fi)\n"
  done
fi

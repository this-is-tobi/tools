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
This script aims to insert or update /etc/hosts file with given values.

Available flags:
  -i    Host IP address to add / update.
  -n    Host name to add / update.
  -h    Print script help.

Example:
  ./manage-etc-hosts.sh \\
    -i '192.168.1.1' \\
    -n 'my-host-name.com'
"

# Functions
print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts hi:n: flag; do
  case "${flag}" in
    i)
      IP_ADDRESS="${OPTARG}";;
    n)
      HOST_NAME="${OPTARG}";;
    h | *)
      print_help
      exit 0;;
  esac
done

# Settings
printf "
Settings:
  > IP_ADDRESS: ${IP_ADDRESS}
  > HOST_NAME: ${HOST_NAME}
"

# Options validation
if [ -z $(echo "$IP_ADDRESS") ] || [ -z $(echo "$HOST_NAME") ]; then
  printf "Wrong arguments, you need to specify which ip address and host name to use. Try it again with flags '-ip <ip_address> -n <host_name>'.
    - ip address: $IP_ADDRESS
    - host name: $HOST_NAME"
  exit 1
fi

# find existing instances in the host file and save the line numbers
MATCHES_IN_HOSTS="$(grep -n $HOST_NAME /etc/hosts | cut -f1 -d:)"
HOST_ENTRY="${IP_ADDRESS}  ${HOST_NAME}"

# Update or add entry
if [ ! -z "$MATCHES_IN_HOSTS" ]; then
  echo "Updating existing hosts entry."
  echo "$MATCHES_IN_HOSTS" | while read -r line ; do
    sudo sed -i '' "${line}s/.*/${HOST_ENTRY}/" /etc/hosts
  done
else
  echo "Adding new hosts entry."
  echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
fi

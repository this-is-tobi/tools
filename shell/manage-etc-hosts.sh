#!/bin/bash

# Colorize terminal
red='\e[0;31m'
no_color='\033[0m'
# Console step increment
i=1


# Declare script helper
TEXT_HELPER="\nThis script aims to insert or update /etc/hosts file with given values.

Following flags are available:

  -i  Host IP address to add / update.

  -n  Host name to add / update.

  -h  Print script help.\n\n"

print_help() {
  printf "$TEXT_HELPER"
}

# Parse options
while getopts i:n:h flag; do
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

if [ -z $(echo "$IP_ADDRESS") ] || [ -z $(echo "$HOST_NAME") ]; then
  printf "Wrong arguments, you need to specify which ip address and host name to use. Try it again with flags '-ip <ip_address> -n <host_name>'.
    - ip address: $IP_ADDRESS
    - host name: $HOST_NAME"
  exit 1
fi

# find existing instances in the host file and save the line numbers
MATCHES_IN_HOSTS="$(grep -n $HOST_NAME /etc/hosts | cut -f1 -d:)"
HOST_ENTRY="${IP_ADDRESS}  ${HOST_NAME}"

printf "\n${red}Info.${no_color} Please enter your password if requested."

if [ ! -z "$MATCHES_IN_HOSTS" ]; then
  echo "Updating existing hosts entry."
  echo "$MATCHES_IN_HOSTS" | while read -r line ; do
    sudo sed -i '' "${line}s/.*/${HOST_ENTRY}/" /etc/hosts
  done
else
  echo "Adding new hosts entry."
  echo "$HOST_ENTRY" | sudo tee -a /etc/hosts > /dev/null
fi

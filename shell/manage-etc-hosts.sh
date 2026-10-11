#!/bin/bash

set -euo pipefail

# Colors
COLOR_OFF='\033[0m'
COLOR_RED='\033[0;31m'

# Defaults
IP_ADDRESS=""
HOST_NAME=""
HOSTS_FILE="/etc/hosts"

# Script helper
TEXT_HELPER="
This script aims to insert or update /etc/hosts file with given values.

The host name is matched as a whole name, never as a substring. It is removed
from every other line of the same address family (other names on those lines
are kept) and mapped to the given IP address, so running the script twice
changes nothing the second time.
sudo is only used when the hosts file is not writable by the current user.

Available flags:
  -f    Hosts file to edit.
        Default: '$HOSTS_FILE'.
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

# Prints the hosts file content with HOST_NAME mapped to IP_ADDRESS.
# The first line already carrying the name keeps its position; inline comments are kept.
update_hosts() {
  awk -v ip="$IP_ADDRESS" -v host="$HOST_NAME" '
    function rebuild(addr, names, comment) {
      line = addr "  " names
      if (comment != "") line = line " " comment
      return line
    }
    /^[ \t]*(#|$)/ { print; next }
    # A name may have one IPv4 and one IPv6 entry: only lines of the same family are touched
    (index($1, ":") > 0) != (index(ip, ":") > 0) { print; next }
    {
      names = ""; comment = ""; found = 0
      for (i = 2; i <= NF; i++) {
        if ($i ~ /^#/) {
          for (j = i; j <= NF; j++) comment = comment (comment == "" ? "" : " ") $j
          break
        }
        if ($i == host) { found = 1; continue }
        names = names (names == "" ? "" : " ") $i
      }
      if (!found) { print; next }
      if (!done && $1 == ip) {
        print; done = 1
      } else if (!done && names == "") {
        print rebuild(ip, host, comment); done = 1
      } else if (names != "") {
        print rebuild($1, names, comment)
      }
    }
    END { if (!done) print ip "  " host }
  ' "$HOSTS_FILE"
}

# Parse options
while getopts hf:i:n: flag; do
  case "${flag}" in
    f)
      HOSTS_FILE="${OPTARG}";;
    i)
      IP_ADDRESS="${OPTARG}";;
    n)
      HOST_NAME="${OPTARG}";;
    h)
      print_help
      exit 0;;
    *)
      print_help >&2
      exit 1;;
  esac
done

# Settings
printf "
Settings:
  > HOSTS_FILE: ${HOSTS_FILE}
  > IP_ADDRESS: ${IP_ADDRESS}
  > HOST_NAME: ${HOST_NAME}
"

# Options validation
if [ -z "$IP_ADDRESS" ] || [ -z "$HOST_NAME" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Arguments missing: ip address (flag -i) and host name (flag -n) are required.\n" >&2
  exit 1
fi
# Both values end up in a system file: only accept plain addresses and names.
if ! printf '%s' "$IP_ADDRESS" | grep -Eq '^[0-9A-Fa-f.:]+$'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid ip address: '%s'.\n" "$IP_ADDRESS" >&2
  exit 1
fi
if ! printf '%s' "$HOST_NAME" | grep -Eq '^[A-Za-z0-9_]([A-Za-z0-9._-]*[A-Za-z0-9_])?$'; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Invalid host name: '%s'.\n" "$HOST_NAME" >&2
  exit 1
fi
if [ ! -f "$HOSTS_FILE" ]; then
  printf "\n${COLOR_RED}Error.${COLOR_OFF} Hosts file '%s' does not exist.\n" "$HOSTS_FILE" >&2
  exit 1
fi

# Build the new content aside, then write it in place so the file keeps its owner and mode
NEW_HOSTS="$(mktemp "${TMPDIR:-/tmp}/hosts.XXXXXX")"
trap 'rm -f "$NEW_HOSTS"' EXIT
update_hosts > "$NEW_HOSTS"

if cmp -s "$NEW_HOSTS" "$HOSTS_FILE"; then
  echo "Hosts entry already up to date."
  exit 0
fi

echo "Updating hosts file."
if [ -w "$HOSTS_FILE" ]; then
  cat "$NEW_HOSTS" > "$HOSTS_FILE"
else
  sudo tee "$HOSTS_FILE" < "$NEW_HOSTS" > /dev/null
fi

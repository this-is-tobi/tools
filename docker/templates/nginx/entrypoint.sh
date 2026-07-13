#!/bin/sh
# Runs as /docker-entrypoint.d/90-runtime-env.sh, sourced by nginx's own
# entrypoint before it execs "nginx -g daemon off", so it must not start
# nginx itself.
set -u

ROOT_DIR="${ROOT_DIR:-/usr/share/nginx/html}"
# Prefix used to find placeholders baked into the build, e.g.:
#   const apiUrl = import.meta.env.VITE_SERVER_HOST || 'runtime-server-host'
KEY_PREFIX="${KEY_PREFIX:-runtime}"

# Space-separated names of environment variables to inject into built JS
# files. Set at build time (edit below) or at runtime (-e VARIABLES="...").
# Example: VARIABLES="SERVER_HOST SERVER_PORT KEYCLOAK_DOMAIN KEYCLOAK_REALM KEYCLOAK_CLIENT_ID KEYCLOAK_REDIRECT_URI"
VARIABLES="${VARIABLES:-}"

if [ -z "$VARIABLES" ]; then
  exit 0
fi

populate() {
  name=$1
  file=$2
  key=$(printf '%s' "$KEY_PREFIX-$name" | tr '[:upper:]_' '[:lower:]-')
  value=$(eval "printf '%s' \"\${$name:-}\"")
  if [ -z "$value" ]; then
    return 0
  fi
  # Escape sed's replacement-side special characters (backslash, delimiter, ampersand).
  escaped_value=$(printf '%s' "$value" | sed -e 's/[\&|]/\\&/g')
  sed -i "s|$key|$escaped_value|g" "$file"
}

echo "Injecting runtime env into JS files under $ROOT_DIR"
find "$ROOT_DIR" -type f -name '*.js' | while IFS= read -r file; do
  for var in $VARIABLES; do
    populate "$var" "$file"
  done
done

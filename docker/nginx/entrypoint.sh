#!/bin/sh

ROOT_DIR=/opt/bitnami/nginx/html
# Prefix that is used to find variables in js files 
# ex: `const test = provess.env.SERVER_HOST || 'nginx-server-host'`
KEY_PREFIX=nginx
# List of variables to inject into js files from environment eval
VARIABLES=(
  # SERVER_HOST
  # SERVER_PORT
  # KEYCLOAK_DOMAIN
  # KEYCLOAK_REALM
  # KEYCLOAK_CLIENT_ID
  # KEYCLOAK_REDIRECT_URI
)

populate () {
  KEY=$(echo "$KEY_PREFIX-$1" | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g')
  VALUE=$(eval "echo \${$1}")
  sed -i 's|'${KEY}'|'${VALUE}'|g' $2
}


echo "Replacing env constants in JS"
for file in $ROOT_DIR/assets/*.js; do
  echo "Processing $file ...";
  for var in ${VARIABLES[*]}; do
    populate $var $file
  done
done

nginx -g 'daemon off;'

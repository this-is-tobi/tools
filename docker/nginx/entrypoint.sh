#!/bin/sh

ROOT_DIR=/opt/bitnami/nginx/html
ENV_DIR=/env

populate () {
  if [ -z $(eval "echo \${$1}") ]; then
    VAR="$(grep "^$1" ${ENV_DIR}/.env | xargs)"
    if [ ! -z "$VAR" ]; then
      export "$(grep "^$1" $ENV_DIR/.env | xargs)"
    fi
  fi

  KEY="$1"
  VALUE=$(eval "echo \${$1}")
  sed -i 's|'${KEY}'|'${VALUE}'|g' $2
}

echo "Replacing env constants in JS assets"
for file in $ROOT_DIR/assets/*.js; do
  echo "Processing $file ...";

  cat ${ENV_DIR}/.env | while read e; do
    [[ "${e:0:1}" == "#" ]] && continue
    populate "$(echo "$e" | cut -d "=" -f 1)" $file
  done
done

export SERVER="$SERVER_HOST:$SERVER_PORT"
cat /default.conf.tpl | envsubst '$SERVER' > /opt/bitnami/nginx/conf/server_blocks/default.conf

nginx -g 'daemon off;'

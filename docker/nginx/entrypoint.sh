#!/bin/sh

ROOT_DIR=/opt/bitnami/nginx
ENV_FILE=/env/.env

populate () {
  if [ -z $(eval "echo \${$1}") ]; then
    VAR="$(grep "^$1" "$ENV_FILE" | xargs)"
    if [ ! -z "$VAR" ]; then
      export "$(grep "^$1" "$ENV_FILE" | xargs)"
    fi
  fi

  KEY="\$${1}"
  VALUE=$(eval "echo \${$1}")
  sed -i 's|'${KEY}'|'${VALUE}'|g' $2
}

echo "Replacing env constants in JS assets"
for file in ${ROOT_DIR%/}/html/assets/*.js; do
  echo "Processing $file ..."

  cat "$ENV_FILE" | while read e; do
    [[ "${e:0:1}" == "#" ]] && continue
    populate "$(echo "$e" | cut -d "=" -f 1)" $file
  done
done

sed -i 's|$SERVER|'${SERVER}'|g' ${ROOT_DIR%/}/conf/server_blocks/default.conf

nginx -g 'daemon off;'

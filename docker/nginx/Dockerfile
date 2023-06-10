# Prod stage
FROM docker.io/bitnami/nginx:1.24.0 AS prod

USER 0

RUN apt update && apt install -y gettext-base

COPY --chown=1001:0 --chmod=770 --from=build /app/build/dist /opt/bitnami/nginx/html/
COPY --chown=1001:0 --chmod=660 ./apps/client/nginx/default.conf.tpl /default.conf.tpl
COPY --chown=1001:0 ./entrypoint.sh /docker-entrypoint-initdb.d/load-env.sh

RUN chown 1001:0 /opt/bitnami/nginx/conf/server_blocks/default.conf \
  && chmod 660 /opt/bitnami/nginx/conf/server_blocks/default.conf

USER 1001

EXPOSE 8080

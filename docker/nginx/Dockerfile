# Prod stage
FROM docker.io/bitnami/nginx:1.25.5 AS prod

USER 0

COPY --chown=1001:0 --chmod=770 --from=build ./dist /opt/bitnami/nginx/html/
COPY --chown=1001:0 --chmod=660 ./apps/client/nginx/nginx.conf /opt/bitnami/nginx/conf/server_blocks/default.conf
COPY --chown=1001:0 ./entrypoint.sh /docker-entrypoint-initdb.d/load-env.sh

RUN chmod 660 /opt/bitnami/nginx/conf/server_blocks/default.conf

USER 1001

EXPOSE 8080

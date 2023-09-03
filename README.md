# Tools :wrench:

Utility tools & scripts

## Docker

- [nginx](./docker/nginx/Dockerfile) *- bitnami/nignx rootless conf with variables substitution*

## Nodejs

- [crypto.mjs](./node/crypto.mjs) *- set of crypto functions*

## Shell

- [add-keycloak-users.sh](./shell/add-keycloak-users.sh) *- add keycloak users for a given keycloak realm*
- [clone-subdir.sh](./shell/clone-subdir.sh) *- clone a subdirectory from a git repository*
- [compose-to-matrix.sh](./shell/compose-to-matrix.sh) *- parse docker-compose file to create github matrix*
- [copy-env-examples.sh](./shell/copy-env-examples.sh) *- copy all git project env\*-examples files to env files*
- [get-keycloak-token.sh](./shell/get-keycloak-token.sh) *- display keycloak token for a given keycloak realm, client and user*
- [manage-etc-hosts.sh](./shell/manage-etc-hosts.sh) *- add or update host ip adress in /etc/hosts*
- [trivy-report.sh](./shell/trivy-report.sh) *- parse trivy json reports to create a markdown summary*

## Tools

- [act](./act/README.md) *- local github action act wrapper*
- [kind](./kind/README.md) *- local kubernetes kind wrapper*

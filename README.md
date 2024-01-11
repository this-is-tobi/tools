# Tools :wrench:

Utility tools & scripts

## Docker

__Utils images :__

- [act-runner](./docker/act-runner/Dockerfile) *- act runner image for local CI tests (ubuntu based).*
- [debug](./docker/debug/Dockerfile) *- debug image with all convenients tools (debian based).*
- [dev](./docker/dev/Dockerfile) *- development image with all convenients tools (debian based).*
- [pg-backup](./docker/pg-backup/Dockerfile) *- helper image to backup postgresql to s3 (ubuntu based).*

__Templates images :__

- [nginx](./docker/nginx/Dockerfile) *- bitnami/nignx rootless conf with variables substitution.*

## Nodejs

- [crypto.mjs](./node/crypto.mjs) *- set of crypto functions.*

## Shell

- [add-keycloak-users.sh](./shell/add-keycloak-users.sh) *- add keycloak users for a given keycloak realm.*
- [clone-subdir.sh](./shell/clone-subdir.sh) *- clone a subdirectory from a git repository.*
- [compose-to-matrix.sh](./shell/compose-to-matrix.sh) *- parse docker-compose file to create github matrix.*
- [copy-env-examples.sh](./shell/copy-env-examples.sh) *- copy all git project env\*-examples files to env files.*
- [delete-ghcr-image.sh](./shell/delete-ghcr-image.sh) *- delete image and subsequent manifests from ghcr.*
- [export-argocd-resources.sh](./shell/export-argocd-resources.sh) *- export ready-to-apply argocd resources.*
- [get-keycloak-token.sh](./shell/get-keycloak-token.sh) *- display keycloak token for the given infos.*
- [manage-etc-hosts.sh](./shell/manage-etc-hosts.sh) *- add or update host ip adress in /etc/hosts.*
- [trivy-report.sh](./shell/trivy-report.sh) *- parse trivy json reports to create a markdown summary.*

## Tools

- [act](./act/README.md) *- local github action act wrapper.*
- [kind](./kind/README.md) *- local kubernetes kind wrapper.*

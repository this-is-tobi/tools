# Tools :wrench:

Utility tools & scripts.

## Docker

__Utils images :__

| Name                                         | Description                                                             | Pull command                                        |
| -------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------- |
| [act-runner](./docker/act-runner/Dockerfile) | *act runner image for local CI tests (ubuntu based).*                   | `docker pull ghcr.io/this-is-tobi/tools/act-runner` |
| [debug](./docker/debug/Dockerfile)           | *debug image with all convenients tools (debian based).*                | `docker pull ghcr.io/this-is-tobi/tools/debug`      |
| [dev](./docker/dev/Dockerfile)               | *development image with all convenients tools (debian based).*          | `docker pull ghcr.io/this-is-tobi/tools/dev`        |
| [pg-backup](./docker/pg-backup/Dockerfile)   | *helper image to backup postgresql to s3 (ubuntu based).*               | `docker pull ghcr.io/this-is-tobi/tools/pg-backup`  |
| [s3-backup](./docker/s3-backup/Dockerfile)   | *helper image to backup s3 bucket to another s3 bucket (debian based).* | `docker pull ghcr.io/this-is-tobi/tools/s3-backup`  |

__Templates images :__

| Name                               | Description                                                |
| ---------------------------------- | ---------------------------------------------------------- |
| [nginx](./docker/nginx/Dockerfile) | *bitnami/nignx rootless conf with variables substitution.* |

## Nodejs

| Name                            | Description                |
| ------------------------------- | -------------------------- |
| [crypto.mjs](./node/crypto.mjs) | *set of crypto functions.* |

## Shell

| Name                                                             | Description                                                    |
| ---------------------------------------------------------------- | -------------------------------------------------------------- |
| [add-keycloak-users.sh](./shell/add-keycloak-users.sh)           | *add keycloak users for a given keycloak realm.*               |
| [clone-subdir.sh](./shell/clone-subdir.sh)                       | *clone a subdirectory from a git repository.*                  |
| [compose-to-matrix.sh](./shell/compose-to-matrix.sh)             | *parse docker-compose file to create github matrix.*           |
| [copy-env-examples.sh](./shell/copy-env-examples.sh)             | *copy all git project env\*-examples files to env files.*      |
| [dump-kube-pg.sh](./shell/dump-kube-pg.sh)                       | *dump / restore postgres database from / to a kubernetes pod.* |
| [delete-ghcr-image.sh](./shell/delete-ghcr-image.sh)             | *delete image and subsequent manifests from ghcr.*             |
| [export-argocd-resources.sh](./shell/export-argocd-resources.sh) | *export ready-to-apply argocd resources.*                      |
| [get-keycloak-token.sh](./shell/get-keycloak-token.sh)           | *display keycloak token for the given infos.*                  |
| [manage-etc-hosts.sh](./shell/manage-etc-hosts.sh)               | *add or update host ip adress in /etc/hosts.*                  |
| [purge-ghcr-tags.sh](./shell/purge-ghcr-tags.sh)                 | *purge ghcr tags older than a given date.*                     |
| [trivy-report.sh](./shell/trivy-report.sh)                       | *parse trivy json reports to create a markdown summary.*       |

## Tools

| Name                     | Description                        |
| ------------------------ | ---------------------------------- |
| [act](./act/README.md)   | *local github action act wrapper.* |
| [kind](./kind/README.md) | *local kubernetes kind wrapper.*   |

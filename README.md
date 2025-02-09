# Tools :wrench:

Utility tools & scripts.

## Devops

### ArgoCD app previews

Templates to configure preview environments with ArgoCD by using the Pull Request Generator. The Pull Request generator uses the API of an SCMaaS provider (GitHub, GitLab, Gitea, Bitbucket, ...) to automatically discover open pull requests within a repository, this fits well with the style of building a test environment when you create a pull request.

- [github-appset.yaml](./devops/argo-cd-app-preview/github-appset.yaml)

> For further information, see [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request).

### Github self-hosted runners

Templates to deploy Github Actions Runners accross a Kubernetes cluster.

- [runner-deployment.yaml](./devops/github-selfhosted-runner/runner-deployment.yaml)

> For further information, see [ARC documentation](https://github.com/actions/actions-runner-controller).

## Docker

### Utils images

| Image                                     | Description                                                             | Dockerfiles                                    |
| ----------------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------- |
| `ghcr.io/this-is-tobi/tools/act-runner`   | *act runner image for local CI tests (ubuntu based).*                   | [Dockerfile](./docker/act-runner/Dockerfile)   |
| `ghcr.io/this-is-tobi/tools/curl`         | *ligthweight image with bash, curl, jq and openssl (alpine based).*     | [Dockerfile](./docker/curl/Dockerfile)         |
| `ghcr.io/this-is-tobi/tools/debug`        | *debug image with all convenients tools (debian based).*                | [Dockerfile](./docker/debug/Dockerfile)        |
| `ghcr.io/this-is-tobi/tools/dev`          | *development image with all convenients tools (debian based).*          | [Dockerfile](./docker/dev/Dockerfile)          |
| `ghcr.io/this-is-tobi/tools/pg-backup`    | *helper image to backup postgresql to s3 (postgres based).*             | [Dockerfile](./docker/pg-backup/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/s3-backup`    | *helper image to backup s3 bucket to another s3 bucket (debian based).* | [Dockerfile](./docker/s3-backup/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/vault-backup` | *helper image to backup vault raft cluster to s3 bucket (vault based).* | [Dockerfile](./docker/vault-backup/Dockerfile) |

__Versions correlation table :__

| Name         | Image version | Base image                         |
| ------------ | ------------- | ---------------------------------- |
| act-runner   | 2.0.2         | `docker.io/ubuntu:24.04`           |
| curl         | 1.1.2         | `docker.io/alpine:3.21.2`          |
| debug        | 2.1.0         | `docker.io/debian:12`              |
| dev          | 2.0.2         | `docker.io/debian:12`              |
| pg-backup    | 3.0.2         | `docker.io/postgres:17.2`          |
| pg-backup    | 2.0.2         | `docker.io/postgres:16.6`          |
| pg-backup    | 1.4.5         | `docker.io/postgres:15.10`         |
| s3-backup    | 1.1.4         | `docker.io/debian:12`              |
| vault-backup | 1.3.0         | `docker.io/hashicorp/vault:1.18.4` |

> [!TIP]
> The backup images are supplied with a sample kubernetes cronjob in their respective folders.

### Templates images

| Name                                         | Description                                                |
| -------------------------------------------- | ---------------------------------------------------------- |
| [nginx](./docker/templates/nginx/Dockerfile) | *bitnami/nignx rootless conf with variables substitution.* |

## Nodejs

| Name                            | Description                |
| ------------------------------- | -------------------------- |
| [crypto.mjs](./node/crypto.mjs) | *set of crypto functions.* |

## Shell

| Name                                                             | Description                                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [backup-kube-pg.sh](./shell/backup-kube-pg.sh)                   | *backup / restore postgres database from / to a kubernetes pod.*            |
| [backup-kube-vault.sh](./shell/backup-kube-vault.sh)             | *backup / restore vault raft cluster from / to a kubernetes pod.*           |
| [clone-subdir.sh](./shell/clone-subdir.sh)                       | *clone a subdirectory from a git repository.*                               |
| [compose-to-matrix.sh](./shell/compose-to-matrix.sh)             | *parse docker-compose file to create github matrix.*                        |
| [copy-env-examples.sh](./shell/copy-env-examples.sh)             | *copy all git project env\*-examples files to env files.*                   |
| [delete-ghcr-image.sh](./shell/delete-ghcr-image.sh)             | *delete image and subsequent manifests from ghcr.*                          |
| [eol-infos.sh](./shell/eol-infos.sh)                             | *get package end of life infos.*                                            |
| [export-argocd-resources.sh](./shell/export-argocd-resources.sh) | *export ready-to-apply argocd resources.*                                   |
| [export-kube-resources.sh](./shell/export-kube-resources.sh)     | *export ready-to-apply kubernetes resources.*                               |
| [init-env-files.sh](./shell/init-env-files.sh)                   | *init `.env` and `.yaml` example files by copying them without `-example`.* |
| [keycloak-add-users.sh](./shell/keycloak-add-users.sh)           | *add keycloak users for a given keycloak realm.*                            |
| [keycloak-get-token.sh](./shell/keycloak-get-token.sh)           | *display keycloak token for the given infos.*                               |
| [keycloak-list-users.sh](./shell/keycloak-list-users.sh)         | *list keycloak users for a given keycloak realm.*                           |
| [keycloak-required-tac.sh](./shell/keycloak-required-tac.sh)     | *add terms and conditions required action to all realm users.*              |
| [manage-etc-hosts.sh](./shell/manage-etc-hosts.sh)               | *add or update host ip adress in /etc/hosts.*                               |
| [purge-ghcr-tags.sh](./shell/purge-ghcr-tags.sh)                 | *purge ghcr tags older than a given date.*                                  |
| [trivy-report.sh](./shell/trivy-report.sh)                       | *parse trivy json reports to create a markdown summary.*                    |
| [update-zsh-completions.sh](./shell/update-zsh-completions.sh)   | *update zsh-completions sources.*                                           |

> [!TIP]
> Using a script directly from a curl command :
> ```sh
> curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/<script_name> | bash -s -- -h
> ```

## Tools

| Name                     | Description                        |
| ------------------------ | ---------------------------------- |
| [act](./act/README.md)   | *local github action act wrapper.* |
| [kind](./kind/README.md) | *local kubernetes kind wrapper.*   |

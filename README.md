# Tools :wrench:

Utility tools & scripts.

## Devops

### ArgoCD app previews

Templates to configure preview environments with ArgoCD by using the Pull Request Generator. The Pull Request generator uses the API of an SCMaaS provider (GitHub, GitLab, Gitea, Bitbucket, ...) to automatically discover open pull requests within a repository, this fits well with the style of building a test environment when you create a pull request.

- [github-appset.yaml](./devops/argo-cd-app-preview/github-appset.yaml)

> For further information, see [ArgoCD documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Pull-Request).

### Github self-hosted runners

Templates to deploy Github Actions Runners accross a Kubernetes cluster.

Using __legacy__ install :
  1. Install [actions-runner-controller](https://github.com/actions/actions-runner-controller) helm chart.
      ```sh
      # Get chart informations

      helm show chart actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
      helm show values actions-runner-controller --repo https://actions-runner-controller.github.io/actions-runner-controller
      ```
  1. Deploy the [runner-deployment.yaml](./devops/github-selfhosted-runner/runner-deployment.yaml).

Using __github__ install :
  1. Install [actions-runner-controller](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/quickstart-for-actions-runner-controller) helm chart.
      ```sh
      # Get chart informations

      helm show chart oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
      helm show values oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
      ```

> For further information, see :
> - [Legacy ARC documentation](https://github.com/actions/actions-runner-controller).
> - [Github ARC documentation](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners-with-actions-runner-controller/about-actions-runner-controller).

## Docker

### Utils images

| Image                                      | Description                                                                       | Dockerfiles                                    |
| ------------------------------------------ | --------------------------------------------------------------------------------- | ---------------------------------------------- |
| `ghcr.io/this-is-tobi/tools/act-runner`    | *act runner image for local CI tests (ubuntu based).*                             | [Dockerfile](./docker/act-runner/Dockerfile)   |
| `ghcr.io/this-is-tobi/tools/debug`         | *debug image with all convenients tools (debian based).*                          | [Dockerfile](./docker/debug/Dockerfile)        |
| `ghcr.io/this-is-tobi/tools/dev`           | *development image with all convenients tools (debian based).*                    | [Dockerfile](./docker/dev/Dockerfile)          |
| `ghcr.io/this-is-tobi/tools/gh-runner`     | *github self hosted runner with common packages (ubuntu based).*                  | [Dockerfile](./docker/gh-runner/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/gh-runner-gpu` | *github self hosted runner with common packages and GPU binaries (ubuntu based).* | [Dockerfile](./docker/gh-runner/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/mc`            | *ligthweight image with tools for s3 manipulations (alpine based).*               | [Dockerfile](./docker/mc/Dockerfile)           |
| `ghcr.io/this-is-tobi/tools/pg-backup`     | *helper image to backup postgresql to s3 (postgres based).*                       | [Dockerfile](./docker/pg-backup/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/s3-backup`     | *helper image to backup s3 bucket to another s3 bucket (debian based).*           | [Dockerfile](./docker/s3-backup/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/vault-backup`  | *helper image to backup vault raft cluster to s3 bucket (vault based).*           | [Dockerfile](./docker/vault-backup/Dockerfile) |

__Versions correlation table :__

| Name          | Image version | Base image                               |
| ------------- | ------------- | ---------------------------------------- |
| act-runner    | 2.0.3         | `docker.io/ubuntu:24.04`                 |
| debug         | 2.1.1         | `docker.io/debian:12`                    |
| dev           | 2.0.3         | `docker.io/debian:12`                    |
| gh-runner     | 1.4.1         | `ghcr.io/actions/actions-runner:2.328.0` |
| gh-runner-gpu | 1.2.1         | `ghcr.io/actions/actions-runner:2.328.0` |
| mc            | 1.1.2         | `docker.io/alpine:3.22.1`                |
| pg-backup     | 3.5.0         | `docker.io/postgres:17.6`                |
| pg-backup     | 2.5.0         | `docker.io/postgres:16.10`               |
| pg-backup     | 1.9.0         | `docker.io/postgres:15.14`               |
| s3-backup     | 1.2.0         | `docker.io/debian:12`                    |
| vault-backup  | 1.6.1         | `docker.io/hashicorp/vault:1.20.1`       |

> [!TIP]
> The backup images are supplied with a sample kubernetes cronjob in their respective folders.

### Templates images

| Name                                         | Description                                                |
| -------------------------------------------- | ---------------------------------------------------------- |
| [nginx](./docker/templates/nginx/Dockerfile) | *bitnami/nignx rootless conf with variables substitution.* |

## Git hooks

| Name                                                              | Type         | Description                                                                                                                 | Config                                                       |
| ----------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| [conventional-commit](./git-hooks/commit-msg/conventional-commit) | `commit-msg` | *pure bash check for [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/) pattern in git commit messages.* | -                                                            |
| [eslint-lint](./git-hooks/pre-commit/eslint-lint)                 | `pre-commit` | *lint js, ts and many more files using [eslint](https://github.com/eslint/eslint).*                                         | [eslint.config.js](./git-hooks/configs/eslint.config.js)     |
| [helm-lint](./git-hooks/pre-commit/helm-lint)                     | `pre-commit` | *lint helm charts using [chart-testing](https://github.com/helm/chart-testing).*                                            | [chart-testing.yaml](./git-hooks/configs/chart-testing.yaml) |
| [signed-commit](./git-hooks/pre-push/signed-commit)               | `pre-push`   | *pure bash check if commits are signed.*                                                                                    | -                                                            |
| [yaml-lint](./git-hooks/pre-commit/yaml-lint)                     | `pre-commit` | *lint yaml using [yamllint](https://github.com/adrienverge/yamllint).*                                                      | [yamllint.yaml](./git-hooks/configs/yamllint.yaml)           |

### Quick Setup

Run the following command to download the hook from the GitHub repository and install it in your current repository:

```sh
# Define the target file and the URL to download from
TARGET_FILE=".git/hooks/<git_hook>"
URL="https://raw.githubusercontent.com/this-is-tobi/tools/main/git-hooks/<git_hook>"

# Check if the target file exists
if [ -f "$TARGET_FILE" ]; then
  # File exists, download the content and remove the shebang from the first line
  curl -fsSL "$URL" | sed '1 s/^#!.*//' >> "$TARGET_FILE"
else
  # File does not exist, create the file with the downloaded content
  curl -fsSL "$URL" -o "$TARGET_FILE"
fi

# Ensure the file is executable
chmod +x "$TARGET_FILE"
```

## Nodejs

| Name                            | Description                |
| ------------------------------- | -------------------------- |
| [crypto.mjs](./node/crypto.mjs) | *set of crypto functions.* |

## Shell

| Name                                                             | Description                                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------- |
| [backup-kube-pg.sh](./shell/backup-kube-pg.sh)                   | *backup / restore postgres database **from** / to a kubernetes pod.*        |
| [backup-kube-vault.sh](./shell/backup-kube-vault.sh)             | *backup / restore vault raft cluster from / to a kubernetes pod.*           |
| [clone-subdir.sh](./shell/clone-subdir.sh)                       | *clone a subdirectory from a git repository.*                               |
| [compose-to-matrix.sh](./shell/compose-to-matrix.sh)             | *parse docker-compose file to create github matrix.*                        |
| [copy-env-examples.sh](./shell/copy-env-examples.sh)             | *copy all git project env\*-examples files to env files.*                   |
| [delete-ghcr-image.sh](./shell/delete-ghcr-image.sh)             | *delete image and subsequent manifests from ghcr.*                          |
| [eol-infos.sh](./shell/eol-infos.sh)                             | *get package end of life infos.*                                            |
| [export-argocd-resources.sh](./shell/export-argocd-resources.sh) | *export ready-to-apply argocd resources.*                                   |
| [export-kube-resources.sh](./shell/export-kube-resources.sh)     | *export ready-to-apply kubernetes resources.*                               |
| [helm-template.sh](./shell/helm-template.sh)                     | *generate helm template.*                                                   |
| [init-env-files.sh](./shell/init-env-files.sh)                   | *init '.env' and '.yaml' example files by copying them without '-example'.* |
| [keycloak-add-clients.sh](./shell/keycloak-add-clients.sh)       | *add keycloak clients for a given keycloak realm.*                          |
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

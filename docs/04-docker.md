# Docker

This section provides a collection of pre-built Docker images and templates designed for various development and operational tasks.

## Utils Images

| Image                                      | Description                                                                       | Dockerfiles                                            |
| ------------------------------------------ | --------------------------------------------------------------------------------- | ------------------------------------------------------ |
| `ghcr.io/this-is-tobi/tools/act-runner`    | *act runner image for local CI tests (ubuntu based).*                             | [Dockerfile](../docker/utils/act-runner/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/debug`         | *debug image with all convenients tools (debian based).*                          | [Dockerfile](../docker/utils/debug/Dockerfile)         |
| `ghcr.io/this-is-tobi/tools/dev`           | *development image with all convenients tools (debian based).*                    | [Dockerfile](../docker/utils/dev/Dockerfile)           |
| `ghcr.io/this-is-tobi/tools/gh-runner`     | *github self hosted runner with common packages (ubuntu based).*                  | [Dockerfile](../docker/utils/gh-runner/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/gh-runner-gpu` | *github self hosted runner with common packages and GPU binaries (ubuntu based).* | [Dockerfile](../docker/utils/gh-runner-gpu/Dockerfile) |
| `ghcr.io/this-is-tobi/tools/homelab-utils` | *helper image used for homelab configuration (alpine based).*                     | [Dockerfile](../docker/utils/homelab-utils/Dockerfile) |
| `ghcr.io/this-is-tobi/tools/mc`            | *ligthweight image with tools for s3 manipulations (alpine based).*               | [Dockerfile](../docker/utils/mc/Dockerfile)            |
| `ghcr.io/this-is-tobi/tools/pg-backup`     | *helper image to backup postgresql to s3 (postgres based).*                       | [Dockerfile](../docker/utils/pg-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/s3-backup`     | *helper image to backup s3 bucket to another s3 bucket (debian based).*           | [Dockerfile](../docker/utils/s3-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/vault-backup`  | *helper image to backup vault raft cluster to s3 bucket (vault based).*           | [Dockerfile](../docker/utils/vault-backup/Dockerfile)  |

**Versions correlation table:**

| Name          | Image version | Base image                               |
| ------------- | ------------- | ---------------------------------------- |
| act-runner    | 2.0.3         | `docker.io/ubuntu:24.04`                 |
| debug         | 2.1.1         | `docker.io/debian:12`                    |
| dev           | 2.0.3         | `docker.io/debian:12`                    |
| gh-runner     | 1.4.1         | `ghcr.io/actions/actions-runner:2.328.0` |
| gh-runner-gpu | 1.2.1         | `ghcr.io/actions/actions-runner:2.328.0` |
| homelab-utils | 0.0.1         | `ghcr.io/actions/alpine:3.22.1`          |
| mc            | 1.1.2         | `docker.io/alpine:3.22.1`                |
| pg-backup     | 3.5.0         | `docker.io/postgres:17.6`                |
| pg-backup     | 2.5.0         | `docker.io/postgres:16.10`               |
| pg-backup     | 1.9.0         | `docker.io/postgres:15.14`               |
| s3-backup     | 1.2.0         | `docker.io/debian:12`                    |
| vault-backup  | 1.6.2         | `docker.io/hashicorp/vault:1.20.2`       |

> [!TIP]
> The backup images are supplied with a sample kubernetes cronjob in their respective folders.

## Template Images

Pre-configured Docker image templates that can be customized for specific use cases.

| Name                                          | Description                                        |
| --------------------------------------------- | -------------------------------------------------- |
| [nginx](../docker/templates/nginx/Dockerfile) | *nignx rootless conf with variables substitution.* |

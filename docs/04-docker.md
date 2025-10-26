# Docker

This section provides a collection of pre-built Docker images and templates designed for various development and operational tasks.

## Prerequisites

- **Docker** or **Podman** container runtime
- **Access to GitHub Container Registry** (ghcr.io) - public images require no authentication
- **Kubernetes cluster** (optional, for backup images with CronJob examples)

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

## Usage Examples

### Development Images

```sh
# Debug container
docker run -it ghcr.io/this-is-tobi/tools/debug:latest

# Development environment
docker run -it -v $(pwd):/workspace -w /workspace ghcr.io/this-is-tobi/tools/dev:latest
```

### Backup Images

```sh
# PostgreSQL backup to S3
docker run \
  -e S3_ENDPOINT=<endpoint> \
  -e S3_BUCKET=<bucket> \
  -e S3_ACCESS_KEY=<key> \
  -e S3_SECRET_KEY=<secret> \
  -e PG_HOST=<host> \
  -e PG_DATABASE=<db> \
  -e PG_USER=<user> \
  -e PG_PASSWORD=<pass> \
  ghcr.io/this-is-tobi/tools/pg-backup:3.5.0 backup

# Vault backup to S3
docker run \
  -e S3_ENDPOINT=<endpoint> \
  -e S3_BUCKET=<bucket> \
  -e VAULT_ADDR=<addr> \
  -e VAULT_TOKEN=<token> \
  ghcr.io/this-is-tobi/tools/vault-backup:1.6.2 backup
```

### Utility Images

```sh
# MinIO Client for S3 operations
docker run -it ghcr.io/this-is-tobi/tools/mc:latest \
  mc alias set myminio <endpoint> <access-key> <secret-key>
```

## Building Images Locally

```sh
# Clone repository
git clone https://github.com/this-is-tobi/tools.git
cd tools/docker/utils/<image-name>

# Build image
docker build -t my-custom-image:latest .

# Multi-architecture build
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t myregistry/image:latest --push .
```

## Template Images

Pre-configured Docker image templates that can be customized for specific use cases.

| Name                                          | Description                                        |
| --------------------------------------------- | -------------------------------------------------- |
| [nginx](../docker/templates/nginx/Dockerfile) | *nignx rootless conf with variables substitution.* |

**Usage:**
```sh
# Copy template
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/nginx/Dockerfile" \
  -o Dockerfile

# Build customized image
docker build -t my-nginx:latest .
```

## Troubleshooting

### Image Pull Issues

```sh
# Login to GHCR if needed
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Verify image exists
# https://github.com/this-is-tobi/tools/pkgs/container/tools
```

### Runtime Issues

**Permission errors:**
- Most images run as non-root user
- Check volume mount permissions
- Use: `docker run --user $(id -u):$(id -g)`

**Out of memory:**
- Increase Docker memory limits
- Check with: `docker stats`

### Backup Image Issues

**Connection failures:**
- Verify endpoints are reachable
- Check credentials are correct
- Ensure TLS/SSL certificates are valid

**Database connection failed:**
- Verify host, port, and credentials
- Check firewall rules
- Test network connectivity

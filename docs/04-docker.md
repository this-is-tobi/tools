# Docker

This section provides a collection of pre-built Docker images and templates designed for various development and operational tasks.

## Prerequisites

- **Docker** or **Podman** container runtime
- **Access to GitHub Container Registry** (ghcr.io) - public images require no authentication
- **Kubernetes cluster** (optional, for backup images with CronJob examples)

## Utils Images

| Image                                           | Description                                                                                       | Status         | Dockerfiles                                            |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------ |
| `ghcr.io/this-is-tobi/tools/act-runner:2.0.4`   | Act runner for running GitHub Actions workflows locally (ubuntu based)                            | Active         | [Dockerfile](../docker/utils/act-runner/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/backup:1.0.2`       | Unified backup utility for PostgreSQL, Vault, Qdrant and S3 using rclone streaming (alpine based) | Active         | [Dockerfile](../docker/utils/backup/Dockerfile)        |
| `ghcr.io/this-is-tobi/tools/curl:1.2.0`         | Lightweight image with curl (debian based)                                                        | Source removed | -                                                      |
| `ghcr.io/this-is-tobi/tools/debug:2.1.2`        | Debug container with networking and troubleshooting tools (debian based)                          | Active         | [Dockerfile](../docker/utils/debug/Dockerfile)         |
| `ghcr.io/this-is-tobi/tools/dev:2.0.4`          | Development container with common development tools (debian based)                                | Active         | [Dockerfile](../docker/utils/dev/Dockerfile)           |
| `ghcr.io/this-is-tobi/tools/gh-runner:1.6.0`    | Self-hosted GitHub Actions runner with common packages (ubuntu based)                             | Active         | [Dockerfile](../docker/utils/gh-runner/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/gh-runner-gp:1.4.0` | Self-hosted GitHub Actions runner with GPU support (ubuntu based)                                 | Active         | [Dockerfile](../docker/utils/gh-runner-gpu/Dockerfile) |
| `ghcr.io/this-is-tobi/tools/homelab-util:0.0.1` | Homelab utility tools collection (alpine based)                                                   | Active         | [Dockerfile](../docker/utils/homelab-utils/Dockerfile) |
| `ghcr.io/this-is-tobi/tools/mc:1.1.3`           | MinIO Client for S3-compatible storage operations (alpine based)                                  | Deprecated     | [Dockerfile](../docker/utils/mc/Dockerfile)            |
| `ghcr.io/this-is-tobi/tools/pg-backup:4.1.0`    | PostgreSQL backup utility with S3 support (postgres based)                                        | Legacy         | [Dockerfile](../docker/utils/pg-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/s3-backup:1.2.0`    | S3 bucket sync and backup utility (debian based)                                                  | Legacy         | [Dockerfile](../docker/utils/s3-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/vault-backup:1.7.0` | HashiCorp Vault backup utility with S3 support (vault based)                                      | Legacy         | [Dockerfile](../docker/utils/vault-backup/Dockerfile)  |

**Status Legend:**
- **Active**: Currently maintained and recommended for use
- **Legacy**: Still functional but superseded by newer images (consider migrating to `backup` image)
- **Deprecated**: Not recommended for new deployments, will be removed in future versions
- **Source removed**: Image still available in registry but source code removed from repository

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

The new unified backup image supports PostgreSQL, Vault, Qdrant, and S3-to-S3 backups with streaming:

```sh
# PostgreSQL backup to S3
docker run --rm \
  -e DB_HOST=<host> \
  -e DB_PORT=5432 \
  -e DB_NAME=<database> \
  -e DB_USER=<user> \
  -e DB_PASS=<password> \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/postgres-backup.sh

# Vault backup to S3
docker run --rm \
  -e VAULT_ADDR=<vault-address> \
  -e VAULT_TOKEN=<token> \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/vault-backup.sh

# Qdrant backup to S3
docker run --rm \
  -e QDRANT_URL=<qdrant-url> \
  -e QDRANT_COLLECTION=<collection-name> \
  -e QDRANT_API_KEY=<api-key> \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/qdrant-backup.sh

# S3-to-S3 sync
docker run --rm \
  -e SOURCE_S3_ENDPOINT=<source-endpoint> \
  -e SOURCE_S3_ACCESS_KEY=<source-key> \
  -e SOURCE_S3_SECRET_KEY=<source-secret> \
  -e SOURCE_S3_BUCKET_NAME=<source-bucket> \
  -e S3_ENDPOINT=<target-endpoint> \
  -e S3_ACCESS_KEY=<target-key> \
  -e S3_SECRET_KEY=<target-secret> \
  -e S3_BUCKET_NAME=<target-bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/s3-backup.sh
```

> [!NOTE]
> Legacy backup images (`pg-backup`, `vault-backup`, `s3-backup`) are still available but consider migrating to the unified `backup` image.

### Utility Images

```sh
# MinIO Client for S3 operations (deprecated - use backup image instead)
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
- Verify endpoints are reachable from the container
- Check credentials are correct (watch for obfuscated values in logs)
- Ensure TLS/SSL certificates are valid

**Database connection failed:**
- Verify host, port, and credentials
- Check firewall rules allow container network access
- Test network connectivity: `docker run --rm ghcr.io/this-is-tobi/tools/debug:latest ping <host>`

**S3 upload failures:**
- Verify S3 endpoint is accessible
- Check bucket permissions and policies
- For large databases (>48GB), add `RCLONE_EXTRA_ARGS="--s3-chunk-size 128Mi"`
- Check available disk space if not using streaming mode

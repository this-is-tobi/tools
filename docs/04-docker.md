# Docker

This section provides a collection of pre-built Docker images and templates designed for various development and operational tasks.

## Prerequisites

- **Docker** or **Podman** container runtime
- **Access to GitHub Container Registry** (ghcr.io) - public images require no authentication
- **Kubernetes cluster** (optional, for backup images with CronJob examples)

## Utils Images

| Image                                            | Description                                                                                                               | Status                | Dockerfiles                                            |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------ |
| `ghcr.io/this-is-tobi/tools/act-runner:2.0.4`    | Act runner for running GitHub Actions workflows locally (ubuntu based)                                                    | Active                | [Dockerfile](../docker/utils/act-runner/Dockerfile)    |
| `ghcr.io/this-is-tobi/tools/backup:1.4.0`        | Unified backup utility for MariaDB, MongoDB, PostgreSQL, etcd, Vault, Qdrant and S3 using rclone streaming (alpine based) | Active                | [Dockerfile](../docker/utils/backup/Dockerfile)        |
| `ghcr.io/this-is-tobi/tools/curl:2.0.3`          | Lightweight image with curl, wget, jq, yq and openssl (alpine based)                                                      | Active                | [Dockerfile](../docker/utils/curl/Dockerfile)          |
| `ghcr.io/this-is-tobi/tools/debug:3.0.1`         | Debug container with networking and troubleshooting tools (debian based)                                                  | Active                | [Dockerfile](../docker/utils/debug/Dockerfile)         |
| `ghcr.io/this-is-tobi/tools/dev:3.0.1`           | Development container with common development tools (debian based)                                                        | Active                | [Dockerfile](../docker/utils/dev/Dockerfile)           |
| `ghcr.io/this-is-tobi/tools/dev-lite:1.0.1`      | Development container with common development tools (lite version, debian based)                                          | Active                | [Dockerfile](../docker/utils/dev-lite/Dockerfile)      |
| `ghcr.io/this-is-tobi/tools/gh-runner:1.11.0`    | Self-hosted GitHub Actions runner with common packages (ubuntu based)                                                     | Active                | [Dockerfile](../docker/utils/gh-runner/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/gh-runner-gpu:1.9.0` | Self-hosted GitHub Actions runner with GPU support (ubuntu based)                                                         | Active                | [Dockerfile](../docker/utils/gh-runner-gpu/Dockerfile) |
| `ghcr.io/this-is-tobi/tools/mc:1.1.3`            | MinIO Client for S3-compatible storage operations (alpine based)                                                          | Source removed        | -                                                      |
| `ghcr.io/this-is-tobi/tools/pg-backup:4.1.0`     | PostgreSQL backup utility with S3 support (postgres based)                                                                | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/pg-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/s3-backup:1.2.0`     | S3 bucket sync and backup utility (debian based)                                                                          | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/s3-backup/Dockerfile)     |
| `ghcr.io/this-is-tobi/tools/vault-backup:1.7.0`  | HashiCorp Vault backup utility with S3 support (vault based)                                                              | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/vault-backup/Dockerfile)  |

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

The new unified backup image supports MariaDB, MongoDB, PostgreSQL, etcd, Vault, Qdrant, and S3-to-S3 backups with streaming:

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

# MariaDB backup to S3
docker run --rm \
  -e DB_HOST=<host> \
  -e DB_PORT=3306 \
  -e DB_NAME=<database> \
  -e DB_USER=<user> \
  -e DB_PASS=<password> \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/mariadb-backup.sh

# MongoDB backup to S3
docker run --rm \
  -e DB_HOST=<host> \
  -e DB_PORT=27017 \
  -e DB_NAME=<database> \
  -e DB_USER=<user> \
  -e DB_PASS=<password> \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/mongodb-backup.sh

# etcd backup to S3
docker run --rm \
  -e ETCD_ENDPOINTS=https://<host>:2379 \
  -e ETCD_CACERT=/certs/ca.crt \
  -e ETCD_CERT=/certs/client.crt \
  -e ETCD_KEY=/certs/client.key \
  -e S3_ENDPOINT=<s3-endpoint> \
  -e S3_ACCESS_KEY=<access-key> \
  -e S3_SECRET_KEY=<secret-key> \
  -e S3_BUCKET_NAME=<bucket> \
  -v /path/to/certs:/certs:ro \
  ghcr.io/this-is-tobi/tools/backup:latest \
  /home/alpine/scripts/etcd-backup.sh

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

## Release & Build Automation

Active images (the `deprecated` images below use static, hand-maintained tags and are excluded from all of this) are versioned and rebuilt automatically. Nothing about publishing a new image version normally requires a manual step.

**End-to-end flow:**

1. A base image gets a new version, or a month goes by → a commit lands on `main` scoped to one image's directory.
2. [`cd.yml`](../.github/workflows/cd.yml) runs `release-please` on every push to `main`. For each image directory with unreleased `fix`/`feat`/breaking commits since its last release, it opens (or updates) an independent release PR bumping that image's version, updating its `CHANGELOG.md`, and bumping its entry in [`.release-please-manifest.json`](../.release-please-manifest.json).
3. Merging a release PR creates a git tag `<image-name>-v<version>` (e.g. `curl-v2.0.4`).
4. That tag push triggers [`build-images.yml`](../.github/workflows/build-images.yml), which looks up the matching entry in `ci/matrix.json` for build metadata (context, Dockerfile, target), resolves the version to build from `.release-please-manifest.json`, and builds/pushes just that one image (multi-arch, plus SBOM + provenance attestations), via the shared [`this-is-tobi/github-workflows`](https://github.com/this-is-tobi/github-workflows) reusable workflows.

Each image versions and releases **independently** — bumping `curl` never touches `debug`'s version or triggers its rebuild.

### Base image updates

[Renovate](https://docs.renovatebot.com/) ([`renovate.json`](../renovate.json)) watches the `ARG BASE_IMAGE=...` default in every active Dockerfile (this is the single source of truth for the base image — `ci/matrix.json` no longer duplicates it) and opens a PR per outdated base, commit-scoped as `fix(...)` so release-please treats it as a patch release for that image. Deprecated images are excluded from Renovate entirely.

### Scheduled dependency refresh

None of these Dockerfiles pin `apt`/`apk` package versions, so a base image bump alone won't catch newer package versions between base image releases. [`refresh-images.yml`](../.github/workflows/refresh-images.yml) runs monthly, touches a `.refresh` marker file inside each active image's directory, and pushes one `fix(docker): scheduled dependency refresh` commit. That's a real, path-scoped commit, so release-please cuts a genuine patch release from it — this is the mechanism that keeps floating packages current without hand-tracking every dependency. Trigger it manually via `workflow_dispatch` with a comma-separated `IMAGES` input to refresh specific images on demand.

### Versioning (release-please)

[`release-please-config.json`](../release-please-config.json) + [`.release-please-manifest.json`](../.release-please-manifest.json) define one [release-please](https://github.com/googleapis/release-please) "package" per active image directory (`docker/utils/<name>`), each with:
- `component`: the image name, used to build the `<name>-v<version>` tag.
- `initial-version`: where that image's version counter starts.
- `bootstrap-sha`: the commit this system was introduced at — release-please only considers commits *after* this SHA for that path. This repo had real unreleased `feat:`/`fix:` history predating this pipeline; without `bootstrap-sha` release-please would walk that entire history on its first run and could bump several images unexpectedly. **Don't remove this field** unless you specifically want release-please to re-scan full history for a package.

`ci/matrix.json` deliberately has **no `tag` field** for actively-released images, and `release-please-config.json` deliberately has **no `extra-files`** pointing back into it. `build-images.yml` resolves each active image's version straight from `.release-please-manifest.json` at build time instead (deprecated images, which aren't release-please-managed, keep a static hand-set `tag` in `matrix.json` as their only source).

> [!WARNING]
> Don't add an `extra-files` entry targeting `ci/matrix.json` (or any other root-level JSON *array* file). Release-please's built-in JSON `extra-files` updater assumes the target file's root is an object — its format-preserving stringifier slices the content before the first `{` and after the last `}` ([`json-stringify.ts`](https://github.com/googleapis/release-please/blob/main/src/util/json-stringify.ts)). Pointed at an array-rooted file, this corrupts it into a doubly-nested array (`[[...]]`) on every patch, silently breaking every `jq '.[] | ...'` consumer. Hit this for real on 2026-07-16 (PR #11, act-runner 2.0.5) — root-caused by reading release-please's source directly, not guessed. If a future release-please version fixes this upstream, it'd be safe to reintroduce `extra-files` here, but verify against a real generated PR diff first.

Release PRs are **not auto-merged** (`AUTOMERGE_RELEASE: false` in `cd.yml`) — review and merge them like any other PR. This matches the convention used in the `github-workflows` repo itself.

### Adding a new image

1. Add its Dockerfile under `docker/utils/<name>/` with `ARG BASE_IMAGE=...` + `FROM ${BASE_IMAGE}` (needed for Renovate to detect it).
2. Add an entry to `ci/matrix.json` (`name`, `description`, `build.context`, `build.dockerfile`, `build.target`, `build.latest`) — **no `build.tag` field**, that's resolved at build time from the manifest.
3. Add a matching package to `release-please-config.json` (`component`, `initial-version` = its starting version, `bootstrap-sha` = current `HEAD` — **no `extra-files`**, see the warning above) and a matching entry to `.release-please-manifest.json` (same starting version).
4. Add its row to the table above and to `docs/04-docker.md`'s docs.

> [!NOTE]
> If an image shares a directory with another (like `dev`/`dev-lite` used to), release-please can't version them independently — a change to either one's Dockerfile bumps both. Give each image its own directory unless you deliberately want lockstep versioning.

### Deprecating an image

Set `"deprecated": true` on its `ci/matrix.json` entry. This excludes it from Renovate, from the scheduled refresh, and from `release-please-config.json`/the manifest (remove its package if present) — it keeps whatever tag it has and is no longer auto-released. It remains buildable via `build-images.yml`'s manual `workflow_dispatch` (explicit `IMAGES` input bypasses the deprecated filter, so you can still force a rebuild — e.g. to patch a CVE — before removing it entirely).

### Manual rebuilds

`build-images.yml` also accepts `workflow_dispatch` with an optional comma-separated `IMAGES` input (leave empty to rebuild every active image). Useful for forcing a rebuild without waiting on a release-please PR.

### PR build checks

`ci.yml` verifies buildability before anything merges, not just commit message format. On every non-draft PR it diffs changed files against `ci/matrix.json`'s `build.context` fields and builds (AMD64 only, no attestation) just the images actually touched, tagged `<image>:pr-<number>` and pushed to ghcr.io — a PR touching only docs or a single Dockerfile builds nothing or exactly that one image. `docker/templates/**` changes get a local `docker build` for both the `dev` and `prod` stages instead (no push — templates were never published by this pipeline, they're copy-paste starting points). PR-tagged images are deleted from ghcr.io once the PR closes (merged or not), via the shared `clean-cache.yml` workflow.

> [!NOTE]
> PRs from forks won't be able to push the check image — `GITHUB_TOKEN` is read-only for `pull_request` events from forks, which GitHub enforces regardless of the `permissions:` requested in the workflow. Not an issue for same-repo branches.

### Known limitations

- **No cosign keyless signing.** The old pipeline signed every published tag with `cosign sign`; the shared `build-docker.yml` workflow's built-in attestation step only forwards SBOM and SLSA provenance, not signing. SBOM/provenance attestations are still generated.
- **No automated image testing yet.** Builds aren't smoke-tested before being tagged `latest`. Options were scoped (post-publish smoke test, a true pre-push gate, or a `TEST_COMMAND` hook proposed upstream in `build-docker.yml`) but deferred.

## Template Images

Pre-configured Docker image templates that can be customized for specific use cases.

| Name                                          | Description                                                                                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| [nginx](../docker/templates/nginx/Dockerfile) | *Bun dev/build + rootless nginx SPA prod image with runtime env substitution, hardened for restricted environments (OpenShift-compatible).* |
| [bun](../docker/templates/bun/Dockerfile)     | *Bun dev/build/prod multi-stage image for APIs, hardened for restricted environments (OpenShift-compatible).*                               |

### nginx (frontend/SPA)

Expects a `package.json` with a Vite-style `dev` script and a `build` script producing `dist/`, and a committed `bun.lock`. Adjust the dev/build commands in the Dockerfile if your app's toolchain differs.

**Usage:**
```sh
# Copy the whole template (Dockerfile + conf + entrypoint) next to your app
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/nginx/Dockerfile" -o Dockerfile
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/nginx/default.conf.template" -o default.conf.template
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/nginx/entrypoint.sh" -o entrypoint.sh

# Dev image, meant to be run with your source bind-mounted over /app for hot reload
docker build --target dev -t my-frontend:dev .
docker run -p 5173:5173 -v "$(pwd):/app" my-frontend:dev

# Production image (build + prod stages, served by nginx)
docker build --target prod -t my-frontend:latest .
docker run -p 8080:8080 -e SERVER=my-backend:3000 my-frontend:latest
```

**Notes:**
- Three stages: `dev` (Vite/similar dev server via `bun run dev -- --host`), `build` (`bun run build` -> `dist`), `prod` (served by rootless nginx).
- `SERVER` sets the `/api` reverse-proxy upstream (`host:port`). It defaults to a harmless loopback placeholder so the container still starts if you don't use `/api`.
- To inject runtime env vars into built JS files (values not baked in at build time), set `VARIABLES="MY_VAR OTHER_VAR"` plus the corresponding `MY_VAR=...` env vars at `docker run` time — see the comments in `entrypoint.sh`.
- The prod image runs as a non-root user with group `0`, and all files it needs to read/write are group-owned and group-writable, so it works unmodified under OpenShift's restricted SCC (arbitrary UID, GID `0`).
- For a `readOnlyRootFilesystem: true` security context, mount writable `emptyDir` volumes at `/tmp` and `/etc/nginx/conf.d` (nginx needs to write its pid/temp files and the templated config at startup).

### bun (API)

Expects a `package.json` with a `build` script (e.g. `bun build ./src/index.ts --outdir dist --target bun`) producing `dist/index.js`, and a committed `bun.lock`. Adjust the entrypoints at the top of the Dockerfile if your app's layout differs.

**Usage:**
```sh
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/bun/Dockerfile" -o Dockerfile
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/docker/templates/bun/.dockerignore" -o .dockerignore

# Dev image, meant to be run with your source bind-mounted over /app for hot reload
docker build --target dev -t my-api:dev .
docker run -p 3000:3000 -v "$(pwd):/app" my-api:dev

# Production image (build + prod stages)
docker build --target prod -t my-api:latest .
docker run -p 3000:3000 my-api:latest
```

**Notes:**
- Three stages: `dev` (hot reload via `bun --watch`), `build` (bundles and prunes to production-only dependencies), `prod` (minimal `distroless` runtime, no shell/package manager).
- The prod image runs as a non-root user with group `0` (OpenShift restricted SCC compatible) and needs no writable volumes even under `readOnlyRootFilesystem: true`.
- The `distroless` prod image has no shell or `wget`/`curl`, so there's no Docker `HEALTHCHECK`; wire an HTTP liveness/readiness probe (e.g. `/healthz`) at the orchestrator level instead.
- `NODE_ENV` is set to `production` before the `build` stage runs, not just at runtime, since bundlers inline `process.env.NODE_ENV` at build time.

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

**Local destination (`LOCAL_PATH`) usage:**
- Mount a host directory into the container and set `LOCAL_PATH` to its path
- S3 env vars (`S3_ENDPOINT`, `S3_ACCESS_KEY`, etc.) are not required when `LOCAL_PATH` is set
- Useful for testing against port-forwarded Kubernetes services or air-gapped environments:
  ```sh
  kubectl port-forward svc/postgres 5432:5432 &
  docker run --rm \
    --network host \
    -v /local/backups:/backups \
    -e DB_HOST=localhost \
    -e DB_PORT=5432 \
    -e DB_NAME=mydb \
    -e DB_USER=user \
    -e DB_PASS=password \
    -e LOCAL_PATH=/backups \
    ghcr.io/this-is-tobi/tools/backup:latest \
    /home/alpine/scripts/postgres-backup.sh
  ```

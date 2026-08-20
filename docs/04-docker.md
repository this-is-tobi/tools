# Docker

This section provides a collection of pre-built Docker images and templates designed for various development and operational tasks.

## Prerequisites

- **Docker** or **Podman** container runtime
- **Access to GitHub Container Registry** (ghcr.io) - public images require no authentication
- **Kubernetes cluster** (optional, for backup images with CronJob examples)

## Utils Images

| Image                                             | Description                                                                                                               | Status                | Dockerfiles                                            | Versions                                                                                        |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| `ghcr.io/this-is-tobi/tools/act-runner:latest`    | Act runner for running GitHub Actions workflows locally (ubuntu based)                                                    | Active                | [Dockerfile](../docker/utils/act-runner/Dockerfile)    | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fact-runner/versions)    |
| `ghcr.io/this-is-tobi/tools/backup:latest`        | Unified backup utility for MariaDB, MongoDB, PostgreSQL, etcd, Vault, Qdrant and S3 using rclone streaming (alpine based) | Active                | [Dockerfile](../docker/utils/backup/Dockerfile)        | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fbackup/versions)        |
| `ghcr.io/this-is-tobi/tools/curl:latest`          | Lightweight image with curl, wget, jq, yq and openssl (alpine based)                                                      | Active                | [Dockerfile](../docker/utils/curl/Dockerfile)          | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fcurl/versions)          |
| `ghcr.io/this-is-tobi/tools/debug:latest`         | Debug container with networking and troubleshooting tools (debian based)                                                  | Active                | [Dockerfile](../docker/utils/debug/Dockerfile)         | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fdebug/versions)         |
| `ghcr.io/this-is-tobi/tools/dev:latest`           | Development container with common development tools (debian based)                                                        | Active                | [Dockerfile](../docker/utils/dev/Dockerfile)           | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fdev/versions)           |
| `ghcr.io/this-is-tobi/tools/dev-lite:latest`      | Development container with common development tools (lite version, debian based)                                          | Active                | [Dockerfile](../docker/utils/dev-lite/Dockerfile)      | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fdev-lite/versions)      |
| `ghcr.io/this-is-tobi/tools/gh-runner:latest`     | Self-hosted GitHub Actions runner with common packages (ubuntu based)                                                     | Active                | [Dockerfile](../docker/utils/gh-runner/Dockerfile)     | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fgh-runner/versions)     |
| `ghcr.io/this-is-tobi/tools/gh-runner-gpu:latest` | Self-hosted GitHub Actions runner with GPU support (ubuntu based)                                                         | Active                | [Dockerfile](../docker/utils/gh-runner-gpu/Dockerfile) | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fgh-runner-gpu/versions) |
| `ghcr.io/this-is-tobi/tools/pg-backup:latest`     | PostgreSQL backup utility with S3 support (postgres based)                                                                | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/pg-backup/Dockerfile)     | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fpg-backup/versions)     |
| `ghcr.io/this-is-tobi/tools/s3-backup:latest`     | S3 bucket sync and backup utility (debian based)                                                                          | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/s3-backup/Dockerfile)     | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fs3-backup/versions)     |
| `ghcr.io/this-is-tobi/tools/vault-backup:latest`  | HashiCorp Vault backup utility with S3 support (vault based)                                                              | Deprecated *(Legacy)* | [Dockerfile](../docker/utils/vault-backup/Dockerfile)  | [Versions](https://github.com/this-is-tobi/tools/pkgs/container/tools%2Fvault-backup/versions)  |

**Status Legend:**
- **Active**: Currently maintained and recommended for use
- **Legacy**: Still functional but superseded by newer images (consider migrating to `backup` image)
- **Deprecated**: Not recommended for new deployments, will be removed in future versions
- **Source removed**: Image still available in registry but source code removed from repository

> [!TIP]
> This table intentionally never lists a specific version number - every image reference uses `:latest`, and the **Versions** column links straight to each image's live tag list on ghcr.io instead. A hardcoded version column would drift the moment any image released again; this doesn't.

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
4. `cd.yml`'s `trigger-build` job then explicitly dispatches [`build-images.yml`](../.github/workflows/build-images.yml) via `workflow_dispatch` (with no `IMAGES` filter, i.e. "check every active image"). This is deliberate, not incidental: `release-please-action` creates its tags using the default `GITHUB_TOKEN`, and GitHub's anti-recursion guard means `push:`-triggered workflows (like `build-images.yml`'s own `tags:` trigger) never fire for events authored by `GITHUB_TOKEN` — `workflow_dispatch` is explicitly exempt from that restriction, which is why `cd.yml` dispatches it directly instead of relying on the tag push itself. Dispatching unconditionally for every active image is safe and cheap: `build-images.yml`'s own skip-if-already-published guard (`docker manifest inspect`) makes it a no-op for every image whose manifest-declared version is already published, so in practice only the image(s) that actually just got a new version end up building.
5. `build-images.yml` looks up each candidate image's build metadata (context, Dockerfile, target) in `ci/matrix.json`, resolves its version from `.release-please-manifest.json`, and builds/pushes the ones that aren't already published (multi-arch, plus SBOM + provenance attestations), via the shared [`this-is-tobi/github-workflows`](https://github.com/this-is-tobi/github-workflows) reusable workflows.

> [!NOTE]
> Discovered this `GITHUB_TOKEN` gap for real on 2026-07-17: `act-runner-v2.0.5`'s tag was pushed by release-please but `build-images.yml` never ran (confirmed via `gh run list` showing zero runs, ever) until `cd.yml`'s `trigger-build` job was added. If a future change to `github-workflows`' `release-app.yml` starts accepting a PAT for the release-please-action `token:` input instead of `GITHUB_TOKEN`, the native tag trigger would start working too and this dispatch step would become redundant (but harmless to leave in place, given the no-op guard).

Each image versions and releases **independently** — bumping `curl` never touches `debug`'s version or triggers its rebuild.

### Base image updates

[Renovate](https://docs.renovatebot.com/) ([`renovate.json`](../renovate.json)) watches the `ARG BASE_IMAGE=...` default in every active Dockerfile (this is the single source of truth for the base image — `ci/matrix.json` no longer duplicates it) and opens a PR per outdated base, commit-scoped as `build(...)` so release-please treats it as a patch release for that image. Deprecated images are excluded from Renovate entirely.

Active bases are pinned as `tag@sha256:...` (`pinDigests`). The tag alone isn't enough: upstream rebuilds floating tags like `debian:13` with new security patches without ever changing the tag string, so a tag-only pin would silently go stale until the next major. With the digest pinned, those rebuilds become a Renovate PR within hours instead of waiting on the monthly refresh below.

The pinned digest is always the **index (manifest-list) digest**, not a per-architecture one — it points at a list of per-platform manifests, so buildx still resolves the right one for each of `linux/amd64` and `linux/arm64`. Pinning a platform-specific digest by mistake (e.g. one copied from `docker pull --platform ...` or a registry UI's per-arch row) breaks the other arch with `no match for platform in manifest`. Read the correct one with `docker buildx imagetools inspect <image>:<tag>` and take the top-level `Digest:`.

### Scheduled dependency refresh

Digest pinning covers the base OS packages, but not everything in these images comes from the base. [`refresh-images.yml`](../.github/workflows/refresh-images.yml) runs monthly, touches a `.refresh` marker file inside each active image's directory, and pushes one `build(docker): scheduled dependency refresh` commit. That's a real, path-scoped commit, so release-please cuts a genuine patch release from it.

What it still covers that a digest bump does not:

| image                                      | drifts outside the base image digest                                                                             |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `curl`, `backup`                           | only the window between upstream rebuilds of the Alpine base, where the apk repositories are already ahead of it |
| `debug`, `dev`, `dev-lite`                 | the mise tools and bat-extras installed at `@latest` by the dotfiles setup scripts                               |
| `act-runner`, `gh-runner`, `gh-runner-gpu` | the docker.com and nvidia apt repositories, ~30 mise tools at `@latest`, and `uv pip install ansible`            |

**Recency guard.** Renovate rebuilds an image within hours of its base moving, and because a changed `FROM` invalidates every layer, that rebuild already reinstalls everything else too. Refreshing an image that was just rebuilt only publishes a version whose contents are identical — which is what made the changelogs read as though the same change had landed twice. So the workflow reads each image's published `:latest` date from the GitHub Packages API and skips anything younger than `MAX_AGE_DAYS` (default 30). The lookup **fails open**: any result it cannot turn into a timestamp falls through to refreshing, since a redundant rebuild is cheap and an image silently skipped for months is not.

Both are overridable on manual dispatch: `IMAGES` (comma-separated) narrows the selection, `MAX_AGE_DAYS` changes the threshold, and `FORCE` refreshes everything selected regardless of age. Each run writes a table to the job summary showing what was refreshed, what was skipped, and why.

Every Dockerfile **copies its marker in** as its first instruction after `FROM`:

```dockerfile
COPY .refresh /etc/.image-refresh
```

This line is what makes the refresh do anything. BuildKit's cache key for a `RUN` is its parent layer plus the command string; a file sitting in the build context that no instruction ever reads never enters a cache key at all. Without the `COPY`, a refresh commit changes nothing BuildKit can see, `cache-from: type=gha` serves every package layer from cache, and the "refreshed" image is published with byte-identical contents. The monthly cron mostly escaped this because GitHub's Actions cache evicts entries after 7 days, so a 30-day-old cache was usually cold anyway — but the on-demand `workflow_dispatch` path, run soon after a build, hit a warm cache and silently did nothing.

> [!NOTE]
> A new image needs this `COPY` and a `.refresh` file in its directory, otherwise it is silently excluded from the refresh mechanism while still appearing in the refresh commit's diff.

### Pinned dotfiles revision

`debug`, `dev` and `dev-lite` build themselves by cloning [dotfiles](https://github.com/this-is-tobi/dotfiles) and running its setup scripts. That clone is pinned to an explicit commit:

```dockerfile
ARG DOTFILES_REF=<40-char sha>
RUN git clone https://github.com/this-is-tobi/dotfiles \
  && git -C dotfiles checkout --quiet "${DOTFILES_REF}" \
  ...
```

Unpinned, these three images would be defined by whatever dotfiles `main` happened to be at build time: two builds of the same commit produce different images, and a bad dotfiles push silently reaches every image built after it with nothing in this repository's history to show for it.

Keeping the pin current takes no manual work in the normal case — a `customManager` in [`renovate.json`](../renovate.json) tracks the branch head and opens a **single grouped PR** bumping all three images together (`groupName: dotfiles pin`), committed as `build` so each affected image still gets its patch release. They deliberately move in lockstep; the pin exists for reproducibility, not to let the images drift apart.

To bump immediately instead of waiting for Renovate, [`shell/bump-dotfiles-ref.sh`](../shell/bump-dotfiles-ref.sh) rewrites every occurrence in one pass:

```sh
./shell/bump-dotfiles-ref.sh              # pin to current dotfiles main
./shell/bump-dotfiles-ref.sh -n           # dry run, show what would change
./shell/bump-dotfiles-ref.sh -r <sha>     # pin to a specific commit
./shell/bump-dotfiles-ref.sh -b develop   # pin to another branch's head
```

It discovers targets by grepping for the `ARG DOTFILES_REF=` line, so an image that adopts the pattern later is picked up with no change to the script.

### Version pins in build args

Renovate's dockerfile manager only reads `FROM` lines, so a version pinned as a build arg is invisible to it and would sit unchanged forever. A second `customManager` in [`renovate.json`](../renovate.json) picks these up, with each pin declaring its own datasource in a preceding comment:

```dockerfile
# renovate: datasource=github-releases depName=hashicorp/vault extractVersion=^v(?<version>.+)$
ARG VAULT_VERSION=2.0.3
# renovate: datasource=docker depName=postgres versioning=docker
ARG PG_VERSION=18
```

The comment is the whole configuration — adding a tracked pin to any active image needs nothing more than the `# renovate:` line above an `ARG <NAME>_VERSION=`, no change to `renovate.json`.

`PG_VERSION` is the major that alpine's `postgresql<major>-client` package name is built from, tracked through the `postgres` image rather than the apk index. A major bump there depends on alpine having published the matching client package; the PR build and smoke test are what catch it if not.

### Versioning (release-please)

[`release-please-config.json`](../release-please-config.json) + [`.release-please-manifest.json`](../.release-please-manifest.json) define one [release-please](https://github.com/googleapis/release-please) "package" per active image directory (`docker/utils/<name>`), each with:
- `component`: the image name, used to build the `<name>-v<version>` tag.
- `initial-version`: where that image's version counter starts.
> [!WARNING]
> `release-please-config.json`'s `changelog-sections` entry for `build` must stay `"hidden": false`. Release-please skips a release PR when the generated notes come out empty, and its notes only include commit types mapped to a **visible** section — the version bump itself then falls through to a patch. `build` is the type used by every Renovate base-image bump *and* by the scheduled refresh, so hiding that section would leave both silently producing no release and therefore no rebuild. JSON takes no comments, hence the note here.

- `bootstrap-sha`: the commit this system was introduced at — release-please only considers commits *after* this SHA for that path. This repo had real unreleased `feat:`/`fix:` history predating this pipeline; without `bootstrap-sha` release-please would walk that entire history on its first run and could bump several images unexpectedly. **Don't remove this field** unless you specifically want release-please to re-scan full history for a package.

`ci/matrix.json` deliberately has **no `tag` field** for actively-released images, and `release-please-config.json` deliberately has **no `extra-files`** pointing back into it. `build-images.yml` resolves each active image's version straight from `.release-please-manifest.json` at build time instead (deprecated images, which aren't release-please-managed, keep a static hand-set `tag` in `matrix.json` as their only source).

> [!WARNING]
> Don't add an `extra-files` entry targeting `ci/matrix.json` (or any other root-level JSON *array* file). Release-please's built-in JSON `extra-files` updater assumes the target file's root is an object — its format-preserving stringifier slices the content before the first `{` and after the last `}` ([`json-stringify.ts`](https://github.com/googleapis/release-please/blob/main/src/util/json-stringify.ts)). Pointed at an array-rooted file, this corrupts it into a doubly-nested array (`[[...]]`) on every patch, silently breaking every `jq '.[] | ...'` consumer. Hit this for real on 2026-07-16 (PR #11, act-runner 2.0.5) — root-caused by reading release-please's source directly, not guessed. If a future release-please version fixes this upstream, it'd be safe to reintroduce `extra-files` here, but verify against a real generated PR diff first.

Release PRs are **not auto-merged** (`AUTOMERGE_RELEASE: false` in `cd.yml`) — review and merge them like any other PR. This matches the convention used in the `github-workflows` repo itself.

### Adding a new image

1. Add its Dockerfile under `docker/utils/<name>/` with `ARG BASE_IMAGE=...` + `FROM ${BASE_IMAGE}` (needed for Renovate to detect it), followed by `COPY .refresh /etc/.image-refresh`, and create an empty `docker/utils/<name>/.refresh` alongside it (see the scheduled refresh above — without both the image is silently excluded from it).
2. Add an entry to `ci/matrix.json` (`name`, `description`, `build.context`, `build.dockerfile`, `build.target`, `build.latest`) — **no `build.tag` field**, that's resolved at build time from the manifest.
3. Add a matching package to `release-please-config.json` (`component`, `initial-version` = its starting version, `bootstrap-sha` = current `HEAD` — **no `extra-files`**, see the warning above) and a matching entry to `.release-please-manifest.json` (same starting version).
4. Add a smoke test at `ci/tests/<name>.sh` (see image testing below) — a missing one fails CI rather than being skipped.
5. Add its row to the table above and to `docs/04-docker.md`'s docs.

> [!NOTE]
> If an image shares a directory with another (like `dev`/`dev-lite` used to), release-please can't version them independently — a change to either one's Dockerfile bumps both. Give each image its own directory unless you deliberately want lockstep versioning.

### Deprecating an image

Set `"deprecated": true` on its `ci/matrix.json` entry. This excludes it from Renovate, from the scheduled refresh, and from `release-please-config.json`/the manifest (remove its package if present) — it keeps whatever tag it has and is no longer auto-released. It remains buildable via `build-images.yml`'s manual `workflow_dispatch` (explicit `IMAGES` input bypasses the deprecated filter, so you can still force a rebuild — e.g. to patch a CVE — before removing it entirely).

### Manual rebuilds

`build-images.yml` also accepts `workflow_dispatch` with an optional comma-separated `IMAGES` input (leave empty to rebuild every active image). Useful for forcing a rebuild without waiting on a release-please PR.

### PR build checks

`ci.yml` verifies buildability before anything merges, not just commit message format. On every non-draft PR it diffs changed files against `ci/matrix.json`'s `build.context` fields and builds (AMD64 only, no attestation) just the images actually touched, tagged `<image>:pr-<number>` and pushed to ghcr.io — a PR touching only docs or a single Dockerfile builds nothing or exactly that one image. `docker/templates/**` changes get a local `docker build` for both the `dev` and `prod` stages instead (no push — templates were never published by this pipeline, they're copy-paste starting points). PR-tagged images are deleted from ghcr.io once the PR closes (merged or not), via the shared `clean-cache.yml` workflow.

### GitHub API rate limit during builds

Six of the eight images install their tooling through `mise`, which resolves every `@latest` against the GitHub API. Unauthenticated that is **60 requests/hour, shared across every runner on the same egress IP** — building the matrix exhausts it, and the `aqua`/`ubi` backends then fail with a `403` that mise treats as permanent rather than retryable. The dotfiles `mise_use` helper retries five times over 50s, which does not outlast a rate-limit window that resets in minutes.

So the build passes a token. It goes in as a **BuildKit build secret**, never a build arg, so it never reaches an image layer or `docker history`:

```yaml
secrets:
  BUILD_SECRETS: |
    github_token=${{ secrets.GITHUB_TOKEN }}
```

```dockerfile
RUN --mount=type=secret,id=github_token,mode=0444 \
  export GITHUB_TOKEN="$(cat /run/secrets/github_token 2> /dev/null || true)" \
  && ...
```

`mode=0444` because these `RUN` steps execute as the non-root image user, and the default secret mount is `0400` owned by root. The `|| true` keeps it optional: a local `docker build` with no secret still works, it just gets the anonymous limit.

### Image size and build residue

Package-manager caches are purged in the same layer that fills them — a later `RUN` cannot shrink an earlier layer:

```dockerfile
&& rm -rf "${HOME}/.cache" "${HOME}/.npm/_cacache" \
  "${HOME}/.local/share/mise/downloads" "${HOME}/go/pkg/mod"
```

These are build residue, not image content: `~/.cache` is XDG's disposable-by-definition location, and the npm content store, the mise download dir and the Go module cache are all re-fetchable. Nothing under them is read at runtime — the smoke tests in `ci/tests` resolve every tool through mise shims and `mise which`.

Leaving them in costs more than disk. Three limits sit downstream of image size, and each fails in a way that looks like something else:

| limit | what it does when exceeded |
|---|---|
| `actions/attest` SBOM ceiling — **16 MiB** | the SBOM attestation is refused, so the image publishes without one |
| Trivy scan timeout — **5m** by default | the scan aborts with a context deadline and writes **no report**, so the image looks unscanned rather than slow |
| `$GITHUB_STEP_SUMMARY` — **1 MiB** | the write is dropped whole, so the job summary comes back empty rather than truncated |

Keep this in mind when adding tooling to an image: anything that runs a package manager during the build should clean up after itself in the same `RUN`.

### Build cache

Every build here is a cold build. `CACHE: false` is set deliberately, in both the release builds and the PR checks — a layer cache cannot pay for itself in this pipeline, for reasons that are structural rather than a matter of tuning:

- **The trigger is the invalidation.** `build-images.yml` skips any `image:tag` already published, so an image is only ever built when its own Dockerfile changed. The change that causes a build is the same change that busts its layers.
- **`.refresh` sits above everything.** Each image copies that marker in before its first `RUN`, by design — see the scheduled refresh section above. When it changes, nothing below it can be restored.
- **There is nothing left to reuse.** These Dockerfiles are two meaningful layers: a package install, then one large setup `RUN`. There is no long tail of cheap layers to fall back on once the second one misses.
- **Caches are scoped per ref.** A cache written by a PR build is invisible to `main`, so a PR can never warm the cache a release build reads.

Meanwhile the cost is real and unconditional: buildx uploads every layer a second time, to the cache backend on top of the registry. On images this size that is minutes added to the end of each build job, on the critical path, whether or not anything is ever restored.

Exporting to a registry instead moves the destination without removing the upload. Inline cache metadata (`type=inline`) does make the export free, but records only the final image's layers — and free reuse of layers that never match is still nothing.

Revisit this if the large `RUN` is ever split into finer, independently-changing layers: a dotfiles bump could then restore the toolchain layers beneath it, and the arithmetic changes. `build-docker.yml` keeps its `CACHE` and `CACHE_MODE` inputs for callers whose images are shaped that way.

> [!NOTE]
> PRs from forks won't be able to push the check image — `GITHUB_TOKEN` is read-only for `pull_request` events from forks, which GitHub enforces regardless of the `permissions:` requested in the workflow. Not an issue for same-repo branches.

### Image testing

Every active image has a smoke test in [`ci/tests/`](../ci/tests/), run on each PR against the `pr-<n>` image that was just built, via the shared `test-docker.yml` workflow. The tests run *inside* the image, so they catch the class of breakage a successful `docker build` cannot: a tool that installed but doesn't execute, a binary that never made it onto `PATH`, a missing shared library. That last one is not hypothetical — trimming the runner images' apt list once dropped `libatomic1`, and `node` shipped exiting 127 on a missing `libatomic.so.1`.

The tests are split in two deliberately, so that routine changes to a Dockerfile or to the dotfiles setup scripts do not require touching them:

**Inventory — derived, never edited.** `probe_mise_shims` enumerates the mise shims directory *inside the image* and, for every binary found, resolves it through `mise which` and checks the dynamic loader can link it. Whatever a Dockerfile or the dotfiles scripts install today is what gets probed today. Adding a tool anywhere needs no edit here.

The linkage check is the important half. It is what catches `node` exiting 127 on a missing `libatomic.so.1` — and it catches it for *every* binary at once, without executing any of them, so there are no per-tool version flags to guess at and nothing interactive to hang on. A static binary (most Go tools) makes `ldd` exit non-zero with "not a dynamic executable", which is correctly not treated as a failure.

**Contract — declared, and small.** Each `ci/tests/<image>.sh` lists only the tools the image exists to provide. These should fail loudly when removed, because dropping one is a breaking change for consumers and deserves a deliberate decision rather than silent absorption. Everything else is the probe's job — keep these lists short.

The three CI runner images share their contract through [`ci/tests/lib-runner.sh`](../ci/tests/lib-runner.sh), so it is stated once rather than three times. `backup` delegates entirely to the healthcheck script it already ships, so the healthcheck and the test cannot disagree. `curl` and `backup` have no mise at all and pass `optional` to the probe.

`lib.sh` puts the mise shims directory on `PATH` explicitly. The runner images export it via `ENV`, but the dotfiles-based images (`debug`, `dev`, `dev-lite`) rely on shell init, which a non-interactive test shell never reads.

A missing `ci/tests/<name>.sh` fails the job rather than skipping it, so a new image cannot be published with no verification at all.

### Vulnerability scanning

Two layers, both through the shared `scan-trivy.yml` workflow:

- **PR report** ([`ci.yml`](../.github/workflows/ci.yml)) — scans the image the PR just built at `CRITICAL,HIGH` and prints the table to the run summary. Reporting, not gating. These images are mostly third-party release binaries, and `ignore-unfixed` filters less than it looks on those: a Go stdlib CVE counts as fixed the moment Go ships the fix, even though the vulnerable artifact is somebody else's prebuilt binary that only a new upstream release can change. Gating on that would mean red PRs waiting on other projects to cut releases, for findings no change here can address. A second job scans `docker/` with Trivy's config scanner for Dockerfile misconfiguration.
- **Scheduled report** ([`scan-images.yml`](../.github/workflows/scan-images.yml)) — weekly, scans every published `:latest` at `CRITICAL,HIGH` and uploads SARIF to the Security tab. Reporting only, never gating. A build-time scan says nothing about an image published three weeks before a CVE was disclosed, which is the case that actually matters. Deprecated images are excluded by default but can be opted in via the `INCLUDE_DEPRECATED` dispatch input — they are no longer released yet remain pullable, so they are the most likely to have accumulated unpatched CVEs.

Each matrix leg uploads under its own `CATEGORY` (`trivy-<image>`). Uploads sharing a category replace one another, so without this the Security tab would only ever show whichever image finished last.

The scan legs each emit a `Cache save failed` warning (`another job may be creating this cache`). That is `actions/cache` inside `aquasecurity/setup-trivy`: all eight legs start together and race to save the same `trivy-binary-<version>-Linux-X64` key, so one wins and the rest warn. It is cosmetic — the losers already have the binary they just downloaded, and the next run restores from the entry the winner wrote. Silencing it means disabling the Trivy cache entirely and re-downloading the binary and the vulnerability database on every leg, which is a worse trade than a warning.

**Accepted findings** live in [`.trivyignore.yaml`](../.trivyignore.yaml), named explicitly via `TRIVYIGNORES` because Trivy only auto-detects the plain `.trivyignore` format, which carries bare rule IDs with nowhere to record a reason. Paths there are relative to the **scan root** (`docker`), not the repository root — the natural guess is wrong and fails silently.

The point of the file is that the config scan report reads as zero findings, so the next real one is visible. Unfiltered it is ~90 lines of deliberate decisions: images that must `sudo` because they run non-root, apt lines not trimmed with `--no-install-recommends`, and sample manifests for the deprecated backup images. Every entry states why in terms of this repository, and an entry whose reason stops being true should be deleted rather than reworded.

### Secret scanning

A third job runs gitleaks over the **full git history** and **fails the PR** on any finding ([`scan-gitleaks.yml`](https://github.com/this-is-tobi/github-workflows/blob/main/.github/workflows/scan-gitleaks.yml), `FAIL_ON_LEAKS: true`).

A gate is only useful if the report is normally empty, so known false positives are allowlisted in [`.gitleaks.toml`](../.gitleaks.toml) — gitleaks auto-detects it at the scan root, so `ci.yml` passes nothing. Two patterns in this repository trip the default rules: the documented `curl … | bash -s -- -u "https://github.com/…"` one-liners, where the `-u` belongs to the piped script rather than to `curl`, and the placeholder key in the node crypto examples.

Allowlist **by value, not by path**, so a genuine credential committed into one of those same files still fails the scan.

Prefer this over `.gitleaksignore`: fingerprints there are `<commit>:<file>:<rule>:<line>`, so every edit to a live file mints a new one and the ignore silently stops applying.

### Signing and attestation

Published images are signed with `cosign` keyless signing and carry SBOM and SLSA provenance attestations, all pushed to the registry (`SIGN`, `SBOM`, `PROVENANCE` in [`build-images.yml`](../.github/workflows/build-images.yml)). Verify a published image with:

```sh
cosign verify ghcr.io/this-is-tobi/tools/<image>:<tag> \
  --certificate-identity-regexp '^https://github.com/this-is-tobi/github-workflows/.github/workflows/attest-docker.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

gh attestation verify oci://ghcr.io/this-is-tobi/tools/<image>:<tag> --owner this-is-tobi
```

The SBOM is a cosign attestation rather than a GitHub one, so `gh attestation verify` above covers the provenance only. Verify the SBOM with:

```sh
cosign verify-attestation --type spdxjson \
  --certificate-identity-regexp '^https://github.com/this-is-tobi/github-workflows/.github/workflows/attest-docker.yml@' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/this-is-tobi/tools/<image>@<digest>
```

> [!IMPORTANT]
> The certificate identity is **`this-is-tobi/github-workflows`**, not this repository. Signing happens inside the reusable `attest-docker.yml`, and GitHub's OIDC token carries the *called* workflow's path as the certificate SAN. Matching against `^https://github.com/this-is-tobi/tools/` fails — and the tempting reaction, dropping the identity constraint, makes the verification meaningless: it would then accept a signature from anyone.

An SBOM for an image this size runs past the 16 MiB ceiling `actions/attest` imposes, and cutting entries to fit would remove exactly the dependency inventory the SBOM is for. cosign has no such limit and is used for every image's SBOM, so one command works regardless of which image you are checking.

PR check builds are not signed or attested — only release builds are.

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
- `dev` and `build` run as the image's built-in non-root `bun` user (uid/gid 1000), not root. With the bind-mount workflow above, if your host UID isn't 1000, either `chown` your project to `1000:1000` or add `--user "$(id -u):$(id -g)"` to the `docker run` so `bun` can write to it.
- `SERVER` sets the `/api` reverse-proxy upstream (`host:port`). It defaults to a harmless placeholder so the container still starts if you don't use `/api`.
- `PORT` sets the port nginx listens on (default `8080`) — match your `-p` mapping to it if you override it. Must stay above 1024 since the image runs as non-root.
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
- `dev` and `build` run as the image's built-in non-root `bun` user (uid/gid 1000), not root. With the bind-mount workflow above, if your host UID isn't 1000, either `chown` your project to `1000:1000` or add `--user "$(id -u):$(id -g)"` to the `docker run` so `bun` can write to it.
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

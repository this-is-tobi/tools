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
4. release-please creates that tag with the repository's GitHub App token, so the tag push starts [`build-images.yml`](../.github/workflows/build-images.yml) through its own `push: tags:` trigger: one run per tag, building only the image the tag names, from the tagged commit. Each tag runs in its own concurrency group, so several release tags pushed together all build instead of cancelling each other's pending runs. Without the App credentials, `cd.yml`'s `trigger-build` job falls back to dispatching `build-images.yml` on `main` (with no `IMAGES` filter, i.e. "check every active image"): GitHub's anti-recursion guard means `push:`-triggered workflows never fire for events authored by `GITHUB_TOKEN`, and `workflow_dispatch` is exempt from that restriction. Those dispatched builds then fail on the missing App credentials (see the rate limit section below), which at least makes the gap visible.
5. `build-images.yml` looks up each candidate image's build metadata (context, Dockerfile, target) in `ci/matrix.json`, resolves its version from `.release-please-manifest.json`, and builds/pushes the ones that aren't already published (multi-arch, plus SBOM + provenance attestations), via the shared [`this-is-tobi/github-workflows`](https://github.com/this-is-tobi/github-workflows) reusable workflows.

> [!NOTE]
> Discovered this `GITHUB_TOKEN` gap for real on 2026-07-17: `act-runner-v2.0.5`'s tag was pushed by release-please but `build-images.yml` never ran (confirmed via `gh run list` showing zero runs, ever) until `cd.yml`'s `trigger-build` job was added. `release-app.yml` has since moved release-please to the App token, which is what makes the native tag trigger work; the dispatch only runs when the App credentials are missing.

Each image versions and releases **independently** — bumping `curl` never touches `debug`'s version or triggers its rebuild.

### Base image updates

[Renovate](https://docs.renovatebot.com/) ([`renovate.json`](../renovate.json)) watches the `ARG BASE_IMAGE=...` default in every active Dockerfile (this is the single source of truth for the base image — `ci/matrix.json` no longer duplicates it) and opens a PR per outdated base, commit-scoped as `build(...)` so release-please treats it as a patch release for that image. Deprecated images are excluded from Renovate entirely.

Active bases are pinned as `tag@sha256:...` (`pinDigests`). The tag alone isn't enough: upstream rebuilds floating tags like `debian:13` with new security patches without ever changing the tag string, so a tag-only pin would silently go stale until the next major. With the digest pinned, those rebuilds become a Renovate PR within hours instead of waiting on the monthly refresh below.

The pinned digest is always the **index (manifest-list) digest**, not a per-architecture one — it points at a list of per-platform manifests, so buildx still resolves the right one for each of `linux/amd64` and `linux/arm64`. Pinning a platform-specific digest by mistake (e.g. one copied from `docker pull --platform ...` or a registry UI's per-arch row) breaks the other arch with `no match for platform in manifest`. Read the correct one with `docker buildx imagetools inspect <image>:<tag>` and take the top-level `Digest:`.

### Update cooldown

Renovate only proposes a new version of an action, a container image, a build-arg pin or a mise tool (`mise.toml`, picked up by Renovate's built-in mise manager wherever it sits under `docker/`) once it has been public for **3 days** (`minimumReleaseAge`). A compromised or broken upstream release is usually caught and pulled within that window, before it reaches CI or an image; security fixes bypass the wait. An update whose source publishes no release date is held rather than raised unchecked, and appears under *Pending Status Checks* on the Dependency Dashboard, where it can be approved by hand. Three exceptions are configured: images from registries other than Docker Hub (`ghcr.io/actions/actions-runner` among them) give no date and are raised without the wait, as are GitHub runner labels; the dotfiles pin has no cooldown at all.

Renovate also raises fixes for known vulnerabilities in npm and other language dependencies from the OSV database (`osvVulnerabilityAlerts`).

### Batched and grouped updates

- **mise toolchain** — every tool in a `docker/utils/<image>/mise.toml` and the `ghcr.io/jdx/mise` image the runner Dockerfiles take the mise binary from move together in one PR, opened at most weekly (Monday before 04:00 UTC). `act-runner` and `gh-runner` share one tool list and must move in step, every such PR rebuilds and releases both, and mise itself releases several times a week. GHCR gives no release date, so for the mise image the weekly batch is the only spacing it gets.
- **`oc`** — pinned in `mise.toml` through mise's conda mapping (`openshift-cli`), which Renovate cannot look up, so it is excluded and bumped by hand: edit both `mise.toml` files (`act-runner` and `gh-runner` move together) and run `mise lock --platform linux-x64,linux-arm64`. openshift/oc tags only minor releases, so its tags are no source for patch versions.
- **`mise.lock`** — Renovate refreshes it in the same PR by running `mise lock` for the bumped tools in mise's safe mode (`MISE_SAFE=1`, mise 2026.7.12 or newer), which needs no `allowedUnsafeExecutions` and so works on the hosted Renovate app. It does not commit the npm/PyPI dependency graphs under `.mise/locks/` (today `yarn` and `yamllint`), so those tools get their own PR with a note to run `mise lock --platform linux-x64,linux-arm64` by hand and push the result; until then their locked build fails rather than installing something unlocked. `.mise/locks/` is in `ignorePaths`, so Renovate's npm and PyPI managers never open PRs against those generated files.
- **Dockerfile frontend** — `# syntax=docker/dockerfile:1@sha256:...` bumps land in one PR for every Dockerfile as `chore`: the frontend changes how a Dockerfile is parsed, not what an image contains, so they release nothing and images pick them up at their next release.

### Scheduled dependency refresh

Digest pinning covers the base OS packages, but not everything in these images comes from the base. [`refresh-images.yml`](../.github/workflows/refresh-images.yml) runs monthly, touches a `.refresh` marker file inside each active image's directory, and opens a pull request from the `refresh-images` branch carrying one `build(docker): scheduled dependency refresh` commit. That's a real, path-scoped commit, so once merged release-please cuts a genuine patch release from it.

The commit is created through the GitHub API with the repository's GitHub App token, not pushed with git: GitHub signs commits an App creates that way, and a pull request opened by the App (unlike one opened with `GITHUB_TOKEN`) runs CI, so the refresh passes through the same checks and the same signed-commit rule as any other change to `main`. There is only ever one refresh pull request: each run rebuilds the branch from `main` and updates the open pull request instead of opening another, so re-running the workflow is also how to rebase it when `main` has moved. The workflow fails without `APP_CLIENT_ID`/`APP_PRIVATE_KEY`.

What it still covers that a digest bump does not:

| image                                      | drifts outside the base image digest                                                                             |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| `curl`, `backup`                           | only the window between upstream rebuilds of the Alpine base, where the apk repositories are already ahead of it |
| `debug`, `dev`, `dev-lite`                 | the mise tools and bat-extras installed at `@latest` by the dotfiles setup scripts                               |
| `act-runner`, `gh-runner`                  | the docker.com apt repository and ansible's dependencies (the mise toolchain and ansible itself are pinned)      |
| `gh-runner-gpu`                            | the NVIDIA apt repository; everything else comes from the pinned `gh-runner` digest                              |

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

The comment is the whole configuration — adding a tracked pin to any Dockerfile under `docker/` needs nothing more than the `# renovate:` line above an `ARG <NAME>_VERSION=`, no change to `renovate.json`.

`PG_VERSION` is the major that alpine's `postgresql<major>-client` package name is built from, tracked through the `postgres` image rather than the apk index. A major bump there depends on alpine having published the matching client package; the PR build and smoke test are what catch it if not.

`act-runner` and `gh-runner` pin `ANSIBLE_VERSION` the same way (`datasource=pypi`). Only the top-level package is pinned: the venv still resolves ansible's own dependencies at build time.

### Pinned runner toolchain (`mise.toml` + `mise.lock`)

`act-runner` and `gh-runner` install their ~35 tools with [mise](https://mise.jdx.dev), and nothing about that install is resolved at build time:

| file (in `docker/utils/<image>/`) | role                                                                                                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `Dockerfile` `ARG MISE_IMAGE`     | the mise binary, copied from mise's own release image `ghcr.io/jdx/mise:<version>@sha256:...` (built from its signed release assets)      |
| `mise.toml`                       | every tool at an exact version, copied to `~/.config/mise/config.toml`                                                                      |
| `mise.lock`                       | per-platform (`linux-x64`, `linux-arm64`) download URL and checksum of every tool, copied to `~/.config/mise/mise.lock`                    |
| `.mise/locks/`                    | the dependency graphs, with hashes, of the npm (`yarn`) and PyPI (`yamllint`) tools; `mise.lock` points at them by a path relative to itself |

The build runs `mise install --locked`: every download comes from the URL in the lock and is checked against its checksum, and a lock that does not cover the config fails the build instead of quietly resolving something else. The build secret `github_token` is still mounted, since mise can still call the GitHub API (release attestation checks, for one).

The mise binary comes from a digest-pinned image rather than `curl https://mise.run | sh`: the digest fixes the exact binary in this repository (an install script, or a checksum file fetched from the same release, can only prove the download was not corrupted), and Renovate's dockerfile manager bumps tag and digest together like any base image.

`python` is in the toolchain because a locked PyPI install needs an interpreter mise manages, so `python`/`python3` on these runners resolve to mise's. It is held on the newest minor ansible-core supports, since the ansible venv uses it too. `yarn` is installed as `npm:@yarnpkg/cli-dist`: mise's default yarn backend is a plugin cloned from its default branch at install time, which nothing pins.

**Bumping.** Renovate's `mise` manager reads `mise.toml` and updates `mise.lock` alongside it, provided it is allowed to run `mise lock` (`allowedUnsafeExecutions` on a self-hosted instance). If a bump arrives without a refreshed lock, the PR build fails at `mise install --locked`; refresh the lock and push it to the same branch. By hand:

```sh
cd docker/utils/gh-runner
# edit the version in mise.toml, then:
mise trust            # once, so mise reads this directory's config
mise lock --platform linux-x64,linux-arm64
```

`mise lock` installs nothing: it reads the versions and fetches the URLs, checksums and dependency graphs from the backends. Locking `yamllint` needs `uv` 0.12.10 or newer and a Python 3.10+ on the machine running it.

`act-runner/mise.toml` and `gh-runner/mise.toml` carry the same list (only their header comments differ), so bump both and copy the lock across:

```sh
cp docker/utils/gh-runner/mise.lock docker/utils/act-runner/mise.lock
rm -rf docker/utils/act-runner/.mise && cp -R docker/utils/gh-runner/.mise docker/utils/act-runner/.mise
```

### gh-runner-gpu builds on gh-runner

`gh-runner-gpu` is `gh-runner` plus the NVIDIA Container Toolkit, so its Dockerfile starts `FROM` the published `ghcr.io/this-is-tobi/tools/gh-runner:<version>@sha256:...` instead of repeating gh-runner's 120 lines, which drifted whenever one copy was edited without the other. The pin is an ordinary base image to Renovate: each gh-runner release turns into a `build(deps)` bump of `gh-runner-gpu`, which releases it.

The trade-off is lag: a gh-runner change reaches gh-runner-gpu one release and one Renovate PR later, rather than in the same commit. Its own monthly refresh only re-runs the NVIDIA layer.

### Dockerfile conventions

- **Pinned frontend.** Every Dockerfile starts with `# syntax=docker/dockerfile:1@sha256:...`, so it parses the same on any builder (several rely on `RUN --mount` and `COPY --chmod`, and the bun template's symbolic `--chmod=a=rX` needs frontend 1.14+). Renovate's dockerfile manager tracks it.
- **Downloads.** Every `curl` in a Dockerfile passes `-f`, so an HTTP error fails the build instead of being saved as the file. A downloaded binary is checked against a checksum (`vault` in `backup`, `mc` in the legacy images), and the docker.com and NVIDIA apt signing keys against their published fingerprints before apt trusts them.
- **Lint.** [`.hadolint.yaml`](../.hadolint.yaml) holds the repository-wide [hadolint](https://github.com/hadolint/hadolint) decisions (trusted registries, unpinned apt/apk packages, `--no-install-recommends`); a decision about one instruction is an inline `# hadolint ignore=` with its reason, next to it. Run it from the repository root:

  ```sh
  hadolint --config .hadolint.yaml docker/utils/*/Dockerfile docker/templates/*/Dockerfile
  ```

  Only warnings and errors fail; the remaining `DL3066` infos (a non-numeric `USER`) are known.

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

A dispatch only publishes when started from `main` or from a release tag (`<name>-v<version>`, which rebuilds that one release from its own commit — with `FORCE`, e.g. to move `latest` back to the newest release when two releases of the same image were built side by side and the older one finished last); from any other branch the run skips. A run builds the Dockerfiles and the release-please manifest of the ref it starts on and signs the result as that release, so a feature branch — or an unmerged release PR's branch — would otherwise ship unreviewed content under a release version, and `FORCE` would overwrite one that already shipped. For the same reason a tag run, pushed or dispatched, fails unless the tagged commit is in `main`'s history: anyone who can push can push a tag onto any commit, and `main`'s ruleset does not cover tags. `cd.yml` and `refresh-images.yml` are restricted to `main` the same way.

### PR build checks

`ci.yml` verifies buildability before anything merges, not just commit message format. On every non-draft PR it diffs changed files against `ci/matrix.json`'s `build.context` fields and builds (AMD64 only, no attestation) just the images actually touched, tagged `<image>:pr-<number>` and pushed to ghcr.io — a PR touching only docs or a single Dockerfile builds nothing or exactly that one image. An image's own smoke test (`ci/tests/<name>.sh`) counts as part of it, and a change to what every image shares — `ci/tests/lib*.sh` or `ci/matrix.json` — builds and tests all of them. `docker/templates/**` changes get a local `docker build` for both the `dev` and `prod` stages instead (no push — templates were never published by this pipeline, they're copy-paste starting points). PR-tagged images are deleted from ghcr.io once the PR closes (merged or not), by [`cleanup-pr.yml`](../.github/workflows/cleanup-pr.yml) through the shared `clean-images.yml` workflow.

Every PR, drafts included, also runs **Lint**: [actionlint](https://github.com/rhysd/actionlint) (with shellcheck over every `run:` block) and [zizmor](https://docs.zizmor.sh/) (a security audit of the workflows), each from its release image pinned by digest. Further linters join that job as extra steps. actionlint's extra runner labels are declared in [`.github/actionlint.yaml`](../.github/actionlint.yaml) and accepted zizmor findings in [`.github/zizmor.yml`](../.github/zizmor.yml), each with its reason.

**`CI status`** is the check to require on `main`. The image jobs are matrix legs named after whichever images a PR touched, so they cannot be required one by one, and a job skipped by its `if:` passes a required check. `CI status` waits on every PR job and fails unless each one passed — or, for the image and template jobs, had nothing to build. It also fails on a draft PR, whose other jobs are all skipped. Add any new PR job to its `needs`. The cleanup on close runs in its own workflow for the same reason: a `ci.yml` run on `closed` would post a skipped `CI status` for the PR's head commit, which would then pass the ruleset.

### GitHub API rate limit during builds

Every image that installs tooling through `mise` reaches the GitHub API during the build: `act-runner` and `gh-runner` install the exact versions pinned in their `mise.lock` but still fetch release assets (and check attestations) through `api.github.com`, and `debug`, `dev` and `dev-lite` resolve each tool's latest release through the dotfiles setup scripts. Unauthenticated that is **60 requests/hour, shared across every runner on the same egress IP** — building the matrix exhausts it, and the `aqua`/`ubi` backends then fail with a `403` that mise treats as permanent rather than retryable. The dotfiles `mise_use` helper retries five times over 50s, which does not outlast a rate-limit window that resets in minutes.

So the build passes a token. It goes in as a **BuildKit build secret**, never a build arg, so it never reaches an image layer or `docker history`. `build-docker.yml` mints it from the repository's GitHub App, narrowed to `contents:read` on this repository:

```yaml
secrets:
  APP_CLIENT_ID: ${{ secrets.APP_CLIENT_ID }}
  APP_PRIVATE_KEY: ${{ secrets.APP_PRIVATE_KEY }}
with:
  BUILD_SECRET_GITHUB_TOKEN: app
```

Never the job's own `GITHUB_TOKEN`: everything a Dockerfile executes can read the secret — `curl https://mise.run | sh`, every tool mise installs, every package postinstall hook — and the build job holds `packages: write`, so a compromised upstream could push over the images being built. Without the App credentials the build fails at its first step rather than falling back to a wider token.

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
> PRs from forks won't be able to build the check image — repository secrets (the App credentials above) are not passed to `pull_request` runs from forks, and `GITHUB_TOKEN` is read-only there, which GitHub enforces regardless of the `permissions:` requested in the workflow. Not an issue for same-repo branches.

### Image testing

Every active image has a smoke test in [`ci/tests/`](../ci/tests/), run on each PR against the `pr-<n>` image that was just built, via the shared `test-docker.yml` workflow. The tests run *inside* the image, so they catch the class of breakage a successful `docker build` cannot: a tool that installed but doesn't execute, a binary that never made it onto `PATH`, a missing shared library. That last one is not hypothetical — trimming the runner images' apt list once dropped `libatomic1`, and `node` shipped exiting 127 on a missing `libatomic.so.1`.

The tests are split in two deliberately, so that routine changes to a Dockerfile or to the dotfiles setup scripts do not require touching them:

**Inventory — derived, never edited.** `probe_mise_shims` enumerates the mise shims directory *inside the image* and, for every binary found, resolves it through `mise which` and checks the dynamic loader can link it. Whatever a Dockerfile or the dotfiles scripts install today is what gets probed today. Adding a tool anywhere needs no edit here.

The linkage check is the important half. It is what catches `node` exiting 127 on a missing `libatomic.so.1` — and it catches it for *every* binary at once, without executing any of them, so there are no per-tool version flags to guess at and nothing interactive to hang on. A static binary (most Go tools) makes `ldd` exit non-zero with "not a dynamic executable", which is correctly not treated as a failure.

For the runner images, `probe_mise_config_installed` adds the other direction: every tool pinned in the image's global mise config must be installed, so a tool cannot drop out of `mise.toml`'s install without failing the test.

**Contract — declared, and small.** Each `ci/tests/<image>.sh` lists only the tools the image exists to provide. These should fail loudly when removed, because dropping one is a breaking change for consumers and deserves a deliberate decision rather than silent absorption. Everything else is the probe's job — keep these lists short.

The three CI runner images share their contract through [`ci/tests/lib-runner.sh`](../ci/tests/lib-runner.sh), so it is stated once rather than three times. `backup` delegates entirely to the healthcheck script it already ships, so the healthcheck and the test cannot disagree. `curl` and `backup` have no mise at all and pass `optional` to the probe.

`lib.sh` puts the mise shims directory on `PATH` explicitly. The runner images export it via `ENV`, but the dotfiles-based images (`debug`, `dev`, `dev-lite`) rely on shell init, which a non-interactive test shell never reads.

A missing `ci/tests/<name>.sh` fails the job rather than skipping it, so a new image cannot be published with no verification at all.

### Vulnerability scanning

Two layers, both through the shared `scan-trivy.yml` workflow:

- **PR gate** ([`ci.yml`](../.github/workflows/ci.yml)) — scans the image the PR just built and **fails the PR** on any `CRITICAL` vulnerability that has a fix available (`ignore-unfixed`), or any `CRITICAL` secret; the table in the run summary lists exactly what blocks. These images are mostly third-party release binaries, and `ignore-unfixed` filters less than it looks on those: a Go stdlib CVE counts as fixed the moment Go ships the fix, even though the vulnerable artifact is somebody else's prebuilt binary that only a new upstream release can change. Such a finding blocks until the tool is updated or dropped, or until it is accepted in `.trivyignore.yaml` (below) with a reason, scoped to that binary's path. A second job scans `docker/` with Trivy's config scanner for Dockerfile misconfiguration; that one reports without gating.
- **Scheduled report** ([`scan-images.yml`](../.github/workflows/scan-images.yml)) — weekly, scans every published `:latest` at `CRITICAL,HIGH` and uploads SARIF to the Security tab. Reporting only, never gating; `HIGH` findings are tracked here rather than on PRs. A build-time scan says nothing about an image published three weeks before a CVE was disclosed, which is the case that actually matters. Deprecated images are excluded by default but can be opted in via the `INCLUDE_DEPRECATED` dispatch input — they are no longer released yet remain pullable, so they are the most likely to have accumulated unpatched CVEs.

Each matrix leg uploads under its own `CATEGORY` (`trivy-<image>`). Uploads sharing a category replace one another, so without this the Security tab would only ever show whichever image finished last.

The scan legs each emit a `Cache save failed` warning (`another job may be creating this cache`). That is `actions/cache` inside `aquasecurity/setup-trivy`: all eight legs start together and race to save the same `trivy-binary-<version>-Linux-X64` key, so one wins and the rest warn. It is cosmetic — the losers already have the binary they just downloaded, and the next run restores from the entry the winner wrote. Silencing it means disabling the Trivy cache entirely and re-downloading the binary and the vulnerability database on every leg, which is a worse trade than a warning.

**Accepted findings** live in [`.trivyignore.yaml`](../.trivyignore.yaml), named explicitly via `TRIVYIGNORES` (by all three scans) because Trivy only auto-detects the plain `.trivyignore` format, which carries bare rule IDs with nowhere to record a reason. Misconfiguration paths there are relative to the **scan root** (`docker`), not the repository root — the natural guess is wrong and fails silently. Image findings (`vulnerabilities`, `secrets`) are matched against file paths inside the image; start those with `**/`. Every entry is scoped with `paths`, so the same finding anywhere else is still reported.

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
- The prod image runs as non-root uid `1001`, but its code is root-owned and read-only (directories `555`, files `444`): the process cannot rewrite what it runs, and an arbitrary OpenShift uid (restricted SCC) can still read it. It needs no writable volumes even under `readOnlyRootFilesystem: true`; if your app writes files, give that path a volume of its own rather than making `/app` writable.
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

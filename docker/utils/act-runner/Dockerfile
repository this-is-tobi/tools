# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

ARG BASE_IMAGE=docker.io/ubuntu:26.04@sha256:f144425ff09be612d6d9ad965196e9cdc23dae1f42110a8a11a3e9a8198759f7
# mise's own distroless release image: the static binary built from its signed
# release assets, nothing else. Pinned by digest, so the binary is fixed by
# this file rather than by whatever an install script serves at build time,
# and Renovate moves tag and digest together like any other base image.
ARG MISE_IMAGE=ghcr.io/jdx/mise:2026.10.19@sha256:6bd2515bf27389f537921fc8c3e5a6579f15cf889a63a8432dc542670174e50a

FROM ${MISE_IMAGE} AS mise

FROM ${BASE_IMAGE} AS build

# Cache-busting marker, rewritten by refresh-images.yml. It has to be copied in
# for the refresh to mean anything: a context file no instruction reads never
# enters a layer's cache key, so every RUN below would be served from the build
# cache and the "refreshed" image would ship the exact same packages.
COPY .refresh /etc/.image-refresh

# A pipe otherwise reports only its last command, so a failed download feeding
# it would go unnoticed.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=runner
ENV HOME=/home/$USER
# Tools install under $MISE_DATA_DIR and are exposed through shims; `mise
# activate` is for interactive shells, so the shims directory goes on PATH
# explicitly. MISE_YES keeps the build non-interactive, and disabling the asdf
# backend keeps installs on backends that verify what they download.
ENV MISE_DATA_DIR="$HOME/.local/share/mise"
ENV MISE_YES=1
ENV MISE_DISABLE_BACKENDS=asdf
ENV PATH="$MISE_DATA_DIR/shims:$HOME/.local/bin:$PATH:$HOME/.cargo/bin"

# Install apt packages
# System utilities only; portable release binaries come from mise below.
# libatomic1 is a runtime dependency of the prebuilt node binary mise
# installs; without it node exits 127 on a missing libatomic.so.1.
# curl, gpg and sudo are prerequisites for the docker repository step and for
# workflows that call sudo at runtime; they share this layer with the rest so
# the package indices are downloaded once rather than fetched, deleted and
# fetched again.
RUN apt-get update -y && apt-get install -y \
  curl \
  gpg \
  jq \
  libatomic1 \
  make \
  pandoc \
  rsync \
  sed \
  sudo \
  tar \
  unzip \
  && rm -rf /var/lib/apt/lists/*

# Install docker
# No sudo here: this stage still runs as root (the runner account is created
# below), so every sudo call was a no-op wrapper around a command that already
# had the privileges it needed.
# The signing key is the trust root for every package from this repository, so
# it is checked against the fingerprint Docker publishes before apt uses it.
RUN install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && GNUPG_TMP="$(mktemp -d)" \
  && gpg --homedir "${GNUPG_TMP}" --batch --show-keys --with-colons /etc/apt/keyrings/docker.asc \
    | grep -x 'fpr:::::::::9DC858229FC7DD38854AE2D88D81803C0EBFCD88:' > /dev/null \
  && rm -rf "${GNUPG_TMP}" \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list \
  && apt-get update \
  && apt-get install -y containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Create the runner user
# Every other published image in this repo ends on a non-root USER; this one
# declared USER/HOME as env vars but never created the account, so it ran as
# root out of a home directory that only existed because mise's installer made
# it. The account is created after the docker install so the `docker` group
# already exists to join, keeps passwordless sudo (workflow steps routinely
# call it) and owns everything installed below.
# The ubuntu base ships a default `ubuntu` account already holding UID 1000, so
# it is removed first rather than letting useradd fail on a duplicate UID.
ARG USER_UID=1000
RUN if id -u ${USER_UID} > /dev/null 2>&1; then userdel -r "$(id -un ${USER_UID})" > /dev/null 2>&1 || true; fi \
  && useradd -l -m -u ${USER_UID} -s /bin/bash ${USER} \
  && usermod -aG docker ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
  && chmod 440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR ${HOME}

# Install mise and the toolchain
# Every tool is pinned in mise.toml, and `--locked` makes the install take each
# download URL and checksum from mise.lock (the npm/PyPI dependency graphs from
# .mise/locks/) instead of resolving anything: a lock that does not cover the
# config fails the build rather than silently resolving something else. The
# lock records its sidecars relative to itself, hence .mise/ next to it.
# GITHUB_TOKEN comes from a build secret, never a build arg, so it stays out of
# the image layers and `docker history`. Downloads come from the URLs in the
# lock, but mise can still call the GitHub API (release attestation checks, for
# one); unauthenticated that is 60 requests/hour shared across every runner on
# the same egress IP. Optional - a local build without the secret still works,
# it just gets the anonymous limit.
# Purge the package-manager caches in the same layer that fills them - a later
# RUN cannot shrink an earlier layer. These are pure build residue: npm's
# content-addressable store alone runs to gigabytes, and shipping it inflates the
# image, the SBOM (which has a 16 MiB attestation ceiling) and the Trivy scan.
COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise
COPY --chown=${USER}:${USER} mise.toml ${HOME}/.config/mise/config.toml
COPY --chown=${USER}:${USER} mise.lock ${HOME}/.config/mise/mise.lock
COPY --chown=${USER}:${USER} .mise/ ${HOME}/.config/mise/.mise/
# The token read keeps `|| true` on purpose (the secret is optional), so there
# is no failure for a separate declaration to surface.
# hadolint ignore=SC2155
RUN --mount=type=secret,id=github_token,mode=0444 \
  export GITHUB_TOKEN="$(cat /run/secrets/github_token 2> /dev/null || true)" \
  && mise install --locked \
  && mise reshim \
  && { chmod -R u+w "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads" 2> /dev/null || true; } \
  && rm -rf "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads"

# Install python packages
# The venv picks up mise's python from PATH. Only ansible itself is pinned:
# its dependencies still resolve at build time.
# renovate: datasource=pypi depName=ansible
ARG ANSIBLE_VERSION=14.5.0
RUN uv venv "${HOME}/.venv" \
  && . "${HOME}/.venv/bin/activate" \
  && uv pip install "ansible==${ANSIBLE_VERSION}" \
  && rm -rf "${HOME}/.cache"

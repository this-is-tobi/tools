ARG BASE_IMAGE=docker.io/ubuntu:26.04@sha256:6df9e8dd1eac389ebfef692c9648449adeb815d01e16e29cd6f3e50fe64ba9a6

FROM ${BASE_IMAGE} AS build

# Cache-busting marker, rewritten by refresh-images.yml. It has to be copied in
# for the refresh to mean anything: a context file no instruction reads never
# enters a layer's cache key, so every RUN below would be served from the build
# cache and the "refreshed" image would ship the exact same packages.
COPY .refresh /etc/.image-refresh

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=runner
ENV HOME=/home/$USER
# Tools install under $MISE_DATA_DIR and are exposed through shims; `mise
# activate` is for interactive shells, so the shims directory goes on PATH
# explicitly. MISE_YES keeps the build non-interactive, MISE_PIN records the
# exact resolved version of every tool in the image, and disabling the asdf
# backend keeps installs on backends that verify what they download.
ENV MISE_DATA_DIR="$HOME/.local/share/mise"
ENV MISE_YES=1
ENV MISE_PIN=1
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
RUN mkdir -m 0755 -p /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" > /etc/apt/sources.list.d/docker.list \
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
  && useradd -m -u ${USER_UID} -s /bin/bash ${USER} \
  && usermod -aG docker ${USER} \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER} \
  && chmod 440 /etc/sudoers.d/${USER}

USER ${USER}
WORKDIR ${HOME}

# Install mise and language runtimes
# npm is not pinned separately: it ships inside the node release.
# GITHUB_TOKEN comes from a build secret, never a build arg, so it stays out of
# the image layers and `docker history`. mise resolves `@latest` through the
# GitHub API; unauthenticated that is 60 requests/hour shared across every runner
# on the same egress IP, and the aqua/ubi backends fail with a 403 that mise
# treats as permanent once it is hit. Optional - a local build without the secret
# still works, it just gets the anonymous limit.

# Purge the package-manager caches in the same layer that fills them - a later
# RUN cannot shrink an earlier layer. These are pure build residue: npm's
# content-addressable store alone runs to gigabytes, and shipping it inflates the
# image, the SBOM (which has a 16 MiB attestation ceiling) and the Trivy scan.
RUN --mount=type=secret,id=github_token,mode=0444 \
  export GITHUB_TOKEN="$(cat /run/secrets/github_token 2> /dev/null || true)" \
  && curl -fsSL https://mise.run | sh \
  && mise use --global \
  node@latest \
  bun@latest \
  pnpm@latest \
  yarn@latest \
  go@latest \
  rust@latest \
  uv@latest \
  && mise reshim \
  && { chmod -R u+w "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads" 2> /dev/null || true; } \
  && rm -rf "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads"

# Install mise packages
# chart-testing, kubescape and scw have no short name in mise's registry, so
# they are addressed through their aqua packages directly. chart-testing
# provides the `ct` binary.
RUN --mount=type=secret,id=github_token,mode=0444 \
  export GITHUB_TOKEN="$(cat /run/secrets/github_token 2> /dev/null || true)" \
  && mise use --global \
  age@latest \
  argo@latest \
  argocd@latest \
  cosign@latest \
  dive@latest \
  github-cli@latest \
  helm@latest \
  helm-docs@latest \
  k6@latest \
  kind@latest \
  krew@latest \
  kubectl@latest \
  kustomize@latest \
  kyverno@latest \
  mc@latest \
  oc@latest \
  rclone@latest \
  sops@latest \
  terraform@latest \
  trivy@latest \
  vault@latest \
  velero@latest \
  yamllint@latest \
  yq@latest \
  aqua:helm/chart-testing@latest \
  aqua:kubescape/kubescape@latest \
  aqua:scaleway/scaleway-cli@latest \
  && mise reshim \
  && { chmod -R u+w "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads" 2> /dev/null || true; } \
  && rm -rf "${HOME}/.cache" "${HOME}/.npm/_cacache" "${MISE_DATA_DIR}/downloads"

# Install python packages
RUN uv venv ${HOME}/.venv \
  && . ${HOME}/.venv/bin/activate \
  && uv pip install ansible \
  && rm -rf "${HOME}/.cache"

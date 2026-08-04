ARG BASE_IMAGE=docker.io/ubuntu:26.04@sha256:3131b4cc82a783df6c9df078f86e01819a13594b865c2cad47bd1bca2b7063bb

FROM ${BASE_IMAGE} AS build

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
RUN apt-get update -y && apt-get install -y \
  curl \
  gpg \
  sudo \
  && rm -rf /var/lib/apt/lists/*
RUN sudo apt-get update -y && sudo apt-get install -y \
  jq \
  make \
  pandoc \
  rsync \
  sed \
  tar \
  unzip \
  && sudo rm -rf /var/lib/apt/lists/*

# Install docker
RUN sudo mkdir -m 0755 -p /etc/apt/keyrings \
  && sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
  && sudo chmod a+r /etc/apt/keyrings/docker.asc \
  && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && sudo apt-get update \
  && sudo apt-get install -y containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin \
  && sudo rm -rf /var/lib/apt/lists/*

# Install mise and language runtimes
# npm is not pinned separately: it ships inside the node release.
RUN curl -fsSL https://mise.run | sh \
  && mise use --global \
  node@latest \
  bun@latest \
  pnpm@latest \
  yarn@latest \
  go@latest \
  rust@latest \
  uv@latest \
  && mise reshim

# Install mise packages
# chart-testing, kubescape and scw have no short name in mise's registry, so
# they are addressed through their aqua packages directly. chart-testing
# provides the `ct` binary.
RUN mise use --global \
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
  && mise reshim

# Install python packages
RUN uv venv ${HOME}/.venv \
  && . ${HOME}/.venv/bin/activate \
  && uv pip install ansible

ARG BASE_IMAGE=ghcr.io/actions/actions-runner:2.336.0@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

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
# libatomic1 is a runtime dependency of the prebuilt node binary mise
# installs; without it node exits 127 on a missing libatomic.so.1.
RUN sudo apt-get update -y && sudo apt-get install -y \
  jq \
  libatomic1 \
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

# Install NVIDIA Container Toolkit
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && sudo chmod a+r /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg \
  && sudo apt-get update \
  && sudo apt-get install -y nvidia-container-toolkit \
  && sudo rm -rf /var/lib/apt/lists/*

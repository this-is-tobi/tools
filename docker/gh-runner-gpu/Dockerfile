ARG BASE_IMAGE=ghcr.io/actions/actions-runner:2.327.0

FROM ${BASE_IMAGE} AS build

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=runner
ENV HOME=/home/$USER
ENV PROTO_HOME="$HOME/.proto"
ENV PATH="$PATH:$PROTO_HOME/shims:$PROTO_HOME/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PROTO_HOME/shims:$PROTO_HOME/bin"

# Install apt packages
RUN curl -fsSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository | sudo bash \
  && sudo apt-get update -y && sudo apt-get install -y \
  age \
  argo \
  argocd \
  awscli \
  cosign \
  dive \
  github-cli\
  helm \
  helm-docs \
  jq \
  k6 \
  kind \
  krew \
  kubectl \
  kubescape \
  kustomize \
  kyverno \
  make \
  mc \
  oc \
  pandoc \
  rclone \
  rsync \
  scw \
  sed \
  sops \
  tar \
  terraform \
  trivy \
  unzip \
  vault \
  velero \
  yamllint \
  yq \
  && sudo rm -rf /var/lib/apt/lists/*

# Install docker
RUN sudo mkdir -m 0755 -p /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && sudo chmod a+r /etc/apt/keyrings/docker.gpg \
  && sudo apt-get update \
  && sudo apt-get install -y containerd.io docker-buildx-plugin docker-ce docker-ce-cli docker-compose-plugin \
  && sudo rm -rf /var/lib/apt/lists/*

# Install proto packages
RUN curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes \
  && proto install bun \
  && proto install node \
  && proto install npm \
  && proto install pnpm \
  && proto install yarn \
  && proto install go \
  && proto install uv \
  && proto install rust

# Install python packages
RUN uv venv ${HOME}/.venv \
  && . ${HOME}/.venv/bin/activate \
  && uv pip install ansible

# Install packages with shell
RUN CT_VERSION=$(curl -fsSL "https://api.github.com/repos/helm/chart-testing/releases/latest" | jq -r '.tag_name' | sed 's/v//g') \
  && curl -fsSL -o /tmp/chart-testing.tar.gz "https://github.com/helm/chart-testing/releases/latest/download/chart-testing_${CT_VERSION}_linux_${TARGETARCH}.tar.gz" \
  && tar -xzf /tmp/chart-testing.tar.gz -C /tmp \
  && sudo mv /tmp/ct /usr/local/bin/ct \
  && chmod +x /usr/local/bin/ct \
  && sudo rm /tmp/chart-testing.tar.gz

# Install NVIDIA Container Toolkit
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && sudo chmod a+r /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg \
  && sudo apt-get update \
  && sudo apt-get install -y nvidia-container-toolkit \
  && sudo rm -rf /var/lib/apt/lists/*

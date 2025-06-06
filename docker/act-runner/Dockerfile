ARG BASE_IMAGE=docker.io/ubuntu:24.04

FROM ${BASE_IMAGE} AS build

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install common packages
RUN apt-get update && apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gawk \
  gettext \
  git \
  gnupg \
  gnupg-agent \
  jq \
  libcurl3-gnutls \
  libcurl4 \
  libgbm-dev \
  libgtk-3-0 \
  libgtk2.0-0 \
  libnotify-dev \
  libnss3 \
  libxss1 \
  libxtst6 \
  libyaml-0-2 \
  lsb-release \
  psmisc \
  python3-pip \
  software-properties-common \
  ssh \
  sudo \
  unzip \
  wget \
  xauth \
  xvfb \
  xz-utils \
  zip \
  zstd \
  && rm -rf /var/lib/apt/lists/*

# Install docker
RUN sudo apt-get install -y ca-certificates curl gnupg \
  && sudo install -m 0755 -d /etc/apt/keyrings \
  && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && sudo chmod a+r /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Install nodejs
RUN apt-get install -y ca-certificates curl gnupg \
  && sudo mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y nodejs \
  && rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash -

# Install bun
RUN curl -fsSL https://bun.sh/install | bash

# Add wakemeops debian repo
RUN curl -sSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository | sudo bash \
  && sudo apt-get update && apt-get install -y \
  act \
  argo \
  argocd \
  github-cli \
  golang-go \
  helm \
  helm-docs \
  kind \
  krew \
  kubectl \
  kustomize \
  minio-client \
  rclone \
  scw \
  terraform \
  trivy \
  vault \
  yq \
  && rm -rf /var/lib/apt/lists/*

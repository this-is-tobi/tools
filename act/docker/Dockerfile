# FROM ubuntu-latest
FROM docker.io/ubuntu:22.04

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# Install packages
RUN apt-get update -y \
  && apt-get install -y \
  ssh \
  lsb-release \
  gnupg \
  gawk \
  libcurl3-gnutls \
  libcurl4 \
  curl \
  git \
  wget \
  sudo \
  gnupg-agent \
  ca-certificates \
  software-properties-common \
  apt-transport-https \
  libyaml-0-2 \
  zstd \
  zip \
  unzip \
  xz-utils \
  psmisc \
  libgtk2.0-0 \
  libgtk-3-0 \
  libgbm-dev \
  libnotify-dev \
  libgconf-2-4 \
  libnss3 \
  libxss1 \
  libasound2 \
  libxtst6 \
  xauth \
  xvfb \
  jq \
  gettext

# Install docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh \
  && sudo sh get-docker.sh \
  && apt-get install -y docker-compose-plugin

# Install nodejs
RUN apt-get install -y ca-certificates curl gnupg \
  && sudo mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list \
  && apt-get update \
  && apt-get install -y nodejs

# Install helm
RUN apt-get install apt-transport-https --yes \
  && curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list \
  && apt-get update \
  && apt-get install -y helm

# Install kubectl
RUN apt-get install -y apt-transport-https \
  && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - \
  && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list \
  && apt-get update \
  && apt-get install -y kubectl

# Install kind
RUN curl -Lo ./kind https://kind.sigs.k8s.io/dl/$(curl --silent https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name')/kind-${TARGETOS}-${TARGETARCH} \
  && chmod +x ./kind \
  && mv ./kind /usr/local/bin/kind

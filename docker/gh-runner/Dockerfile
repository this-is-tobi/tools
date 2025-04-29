ARG BASE_IMAGE=ghcr.io/actions/actions-runner:2.323.0

FROM ${BASE_IMAGE} AS build

# Set system env
ARG TARGETOS
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=runner
ENV HOME=/home/$USER
ENV PROTO_HOME="$HOME/.proto"
ENV PATH="$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"

# Install apt packages
RUN curl -fsSL https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository | sudo bash \
  && sudo apt-get update -y && sudo apt-get install -y \
  age \
  argo \
  argocd \
  awscli \
  # chart-testing \
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

# Install proto packages
RUN curl -fsSL https://moonrepo.dev/install/proto.sh | bash -s -- --yes && \
  proto install bun && \
  proto install node && \
  proto install npm && \
  proto install pnpm && \
  proto install yarn && \
  proto install go && \
  proto install python && \
  proto install uv && \
  proto install rust

# Install python packages
RUN pip install --user ansible

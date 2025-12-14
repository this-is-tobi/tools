ARG BASE_IMAGE=docker.io/alpine:3.23.0

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=ohmlab
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG VAULT_VERSION=1.21.0
ARG HOME=/home/${USERNAME}
ENV HOME=${HOME}

# Set working directory
WORKDIR ${HOME}

# Install required packages
RUN apk add --no-cache \
  age \
  bash \
  ca-certificates \
  curl \
  jq \
  git \
  gzip \
  helm \
  kubectl \
  openssl \
  rclone \
  unzip \
  tar \
  yq \
  zip \
  && rm -rf /var/cache/apk/*

# Install Vault
RUN curl -fsSL https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip -o vault.zip \
  && unzip vault.zip -d /usr/bin/ \
  && chmod +x /usr/bin/vault \
  && rm vault.zip

# Create non-root user
RUN addgroup -g ${USER_GID} ${USERNAME} \
  && adduser -D -h ${HOME} -s /bin/bash -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} \
  && chgrp -R 0 ${HOME} \
  && chmod -R g=u ${HOME}

# Copy scripts
COPY --chown=${USER_UID}:${USER_GID} ./scripts/ ${HOME}/scripts/
RUN chmod +x ${HOME}/scripts/*.sh

# Set user
USER ${USERNAME}

# Default command
CMD ["/bin/bash"]

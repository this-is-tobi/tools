ARG BASE_IMAGE=docker.io/alpine:3.22.2

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=alpine
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG VAULT_VERSION=1.21.1
ARG PG_VERSION=17
ARG HOME=/home/${USERNAME}
ENV HOME=${HOME}

WORKDIR ${HOME}

# Install packages
RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  jq \
  mariadb-client \
  postgresql${PG_VERSION}-client \
  rclone \
  unzip \
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

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD ${HOME}/scripts/healthcheck.sh || exit 1

# Switch to non-root user
USER ${USERNAME}

# Default entrypoint
ENTRYPOINT ["/bin/sh", "-c", "${HOME}/scripts/entrypoint.sh"]

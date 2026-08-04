ARG BASE_IMAGE=docker.io/alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

FROM ${BASE_IMAGE} AS build

# Cache-busting marker, rewritten by refresh-images.yml. It has to be copied in
# for the refresh to mean anything: a context file no instruction reads never
# enters a layer's cache key, so every RUN below would be served from the build
# cache and the "refreshed" image would ship the exact same packages.
COPY .refresh /etc/.image-refresh

ARG TARGETARCH
ARG USERNAME=alpine
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
# Tracked by the `# renovate:` customManager in renovate.json - Renovate's
# dockerfile manager only reads FROM lines, so without these comments both pins
# would sit here untouched forever.
# renovate: datasource=github-releases depName=hashicorp/vault extractVersion=^v(?<version>.+)$
ARG VAULT_VERSION=2.0.3
# postgresql<major>-client is what alpine names the package, so the major is
# tracked through the postgres image rather than the apk index.
# renovate: datasource=docker depName=postgres versioning=docker
ARG PG_VERSION=18
ARG HOME=/home/${USERNAME}
ENV HOME=${HOME}

WORKDIR ${HOME}

# Install packages
RUN apk add --no-cache \
  bash \
  ca-certificates \
  curl \
  etcd-ctl \
  jq \
  mariadb-client \
  mongodb-tools \
  postgresql${PG_VERSION}-client \
  rclone \
  unzip \
  yq \
  zip \
  && rm -rf /var/cache/apk/*

# Install Vault
# The only binary in this image not fetched by a package manager, so the
# checksum is verified explicitly - releases.hashicorp.com publishes a
# SHA256SUMS file next to every archive. Without this an interrupted or
# tampered download is unpacked and marked executable without complaint.
# The archive keeps its published name so it matches the SHA256SUMS entry, and
# the single relevant line is grepped into its own file rather than piped: grep
# exits non-zero when the arch isn't listed, whereas `sha256sum -c` fed an empty
# stdin is not reliably an error across implementations.
RUN VAULT_ZIP="vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}" -o "${VAULT_ZIP}" \
  && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" -o vault.sums \
  && grep " ${VAULT_ZIP}\$" vault.sums > vault.sum \
  && sha256sum -c vault.sum \
  && unzip "${VAULT_ZIP}" -d /usr/bin/ \
  && chmod +x /usr/bin/vault \
  && rm "${VAULT_ZIP}" vault.sums vault.sum

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

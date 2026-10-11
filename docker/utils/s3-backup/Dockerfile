# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

ARG BASE_IMAGE=docker.io/debian:12

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
# A user name, not a credential: DL3064 matches on the word alone.
# hadolint ignore=DL3064
ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV HOME=/home/${USERNAME}
# dl.min.io stopped serving the mc client (it answers 410 Gone), so the binary
# comes from its GitHub release instead. This image is deprecated and excluded
# from Renovate, so the release and its checksums are pinned here outright.
ARG MC_VERSION=RELEASE.2025-08-13T08-35-41Z
ARG MC_SHA256_AMD64=01f866e9c5f9b87c2b09116fa5d7c06695b106242d829a8bb32990c00312e891
ARG MC_SHA256_ARM64=14c8c9616cfce4636add161304353244e8de383b2e2752c0e9dad01d4c27c12c

WORKDIR ${HOME}
RUN groupadd -g ${USER_UID} ${USERNAME} && useradd -l -m -d ${HOME} -s /bin/bash -g ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
RUN apt-get update && apt-get install -y ca-certificates wget && rm -rf /var/lib/apt/lists/* \
  && case "${TARGETARCH}" in \
    amd64) MC_SHA256="${MC_SHA256_AMD64}" ;; \
    arm64) MC_SHA256="${MC_SHA256_ARM64}" ;; \
    *) echo "no mc checksum pinned for ${TARGETARCH}" >&2; exit 1 ;; \
  esac \
  && wget -q -O /tmp/mc "https://github.com/minio/mc/releases/download/${MC_VERSION}/mc.linux-${TARGETARCH}.${MC_VERSION}" \
  && printf '%s  %s\n' "${MC_SHA256}" /tmp/mc > /tmp/mc.sha256 \
  && sha256sum -c /tmp/mc.sha256 \
  && mv /tmp/mc /usr/bin/mc && chmod +x /usr/bin/mc && rm /tmp/mc.sha256
COPY --chown=${USERNAME}:root ./backup.sh ./backup.sh
USER ${USERNAME}

ENTRYPOINT ["/bin/sh", "./backup.sh"]

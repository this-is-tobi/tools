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
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}
RUN apk add --no-cache \
  bash \
  curl \
  jq \
  openssl \
  wget \
  yq
RUN addgroup -g ${USER_UID} ${USERNAME} && adduser -D -h ${HOME} -s /bin/bash -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
USER ${USERNAME}

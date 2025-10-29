ARG BASE_IMAGE=docker.io/alpine:3.22.2

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=alpine
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}
RUN apk add \
  bash \
  curl \
  jq \
  openssl \
  wget \
  yq \
  && rm -rf /var/cache/apk/* \
  && wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc
RUN addgroup -g ${USER_UID} ${USERNAME} && adduser -D -h ${HOME} -s /bin/bash -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
USER ${USERNAME}

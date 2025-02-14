ARG BASE_IMAGE=docker.io/alpine:3.21.2

FROM ${BASE_IMAGE} AS build

ARG USERNAME=alpine
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}
RUN apk add \
  age \
  bash \
  curl \
  jq \
  openssl \
  yq \
  && rm -rf /var/cache/apk/*
RUN addgroup -g ${USER_UID} ${USERNAME} && adduser -D -h ${HOME} -s /bin/bash -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
USER ${USERNAME}

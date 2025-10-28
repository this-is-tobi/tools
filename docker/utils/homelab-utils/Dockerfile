ARG BASE_IMAGE=docker.io/alpine:3.22.2

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=homelab
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV HOME=/home/${USERNAME}
ARG VAULT_VERSION=1.20.2

WORKDIR ${HOME}
RUN apk add \
  bash \
  curl \
  helm \
  jq \
  kubectl \
  openssl \
  wget \
  yq \
  && rm -rf /var/cache/apk/* \
  && RUN curl -LO "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
  && unzip vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip \
  && mv vault /usr/local/bin/ \
  && rm vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip
RUN addgroup -g ${USER_UID} ${USERNAME} && adduser -D -h ${HOME} -s /bin/bash -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
USER ${USERNAME}
RUN mkdir -p /scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh
CMD ["/bin/bash"]

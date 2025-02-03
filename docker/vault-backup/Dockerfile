ARG BASE_IMAGE=docker.io/hashicorp/vault:1.18.4

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=vault
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}
RUN chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc
COPY --chown=${USERNAME}:root ./backup.sh ./backup.sh
USER ${USERNAME}

ENTRYPOINT ["/bin/sh", "./backup.sh"]

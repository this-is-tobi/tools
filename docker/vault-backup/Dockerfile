FROM docker.io/hashicorp/vault:1.17.2 AS build

ARG TARGETARCH
ENV HOME=/home/vault

WORKDIR $HOME
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc \
  && chgrp -R 0 "$HOME" && chmod -R g=u "$HOME"
COPY --chown=vault:root ./backup.sh ./backup.sh
USER vault

ENTRYPOINT [ "/bin/sh", "./backup.sh" ]

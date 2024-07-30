FROM docker.io/hashicorp/vault:1.17.2 AS build

ARG TARGETARCH
ENV HOME=/home/vault

WORKDIR /home/vault
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc \
  && chgrp -R 0 /home/vault && chmod -R g=u /home/vault
COPY --chown=vault:root ./backup.sh ./backup.sh
USER vault

ENTRYPOINT [ "/bin/sh", "/home/vault/backup.sh" ]

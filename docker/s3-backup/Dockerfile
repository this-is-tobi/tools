FROM docker.io/debian:12 AS build

ARG TARGETARCH
ENV HOME=/home/debian

WORKDIR $HOME
RUN apt update && apt install -y ca-certificates wget && rm -rf /var/lib/apt/lists/*
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc \
  && chgrp -R 0 "$HOME" && chmod -R g=u "$HOME"
COPY --chown=debian:root ./backup.sh ./backup.sh
USER debian

ENTRYPOINT [ "/bin/sh", "./backup.sh" ]

FROM docker.io/postgres:15.7 AS build

ARG TARGETARCH
ENV HOME=/home/postgres

WORKDIR $HOME
RUN apt update && apt install -y ca-certificates wget && rm -rf /var/lib/apt/lists/*
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc \
  && chgrp -R 0 "$HOME" && chmod -R g=u "$HOME"
COPY --chown=postgres:root ./backup.sh ./backup.sh
USER postgres

ENTRYPOINT [ "/bin/sh", "./backup.sh" ]

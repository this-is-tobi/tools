FROM docker.io/hashicorp/vault:1.17.2 AS build

ARG TARGETARCH

RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc && mv mc /usr/bin && chmod +x /usr/bin/mc

COPY ./backup.sh ./backup.sh

ENTRYPOINT [ "/bin/sh", "./backup.sh" ]

FROM docker.io/postgres:15.4 AS build

ARG TARGETARCH

RUN apt update && apt install -y ca-certificates wget && apt clean
RUN wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc && mv mc /usr/bin && chmod +x /usr/bin/mc

COPY ./backup.sh ./backup.sh

ENTRYPOINT [ "/bin/bash", "./backup.sh" ]

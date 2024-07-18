FROM docker.io/hashicorp/vault:1.17.2 AS build

COPY ./backup.sh ./backup.sh

ENTRYPOINT [ "/bin/sh", "./backup.sh" ]

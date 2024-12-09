ARG BASE_IMAGE=docker.io/debian:12

FROM ${BASE_IMAGE} AS build

ARG TARGETARCH
ARG USERNAME=debian
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV HOME=/home/${USERNAME}

WORKDIR ${HOME}
RUN groupadd -g ${USER_UID} ${USERNAME} && useradd -m -d ${HOME} -s /bin/bash -g ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && chown -R ${USERNAME}:root ${HOME} && chgrp -R 0 ${HOME} && chmod -R g=u ${HOME}
RUN apt update && apt install -y ca-certificates wget && rm -rf /var/lib/apt/lists/* \
  && wget https://dl.min.io/client/mc/release/linux-${TARGETARCH}/mc \
  && mv mc /usr/bin && chmod +x /usr/bin/mc
COPY --chown=${USERNAME}:root ./backup.sh ./backup.sh
USER ${USERNAME}

ENTRYPOINT ["/bin/sh", "./backup.sh"]

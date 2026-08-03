ARG BASE_IMAGE=docker.io/debian:13@sha256:fac46bff2e02f51425b6e33b0e1169f55dfb053d83511ca28aa50c09fd5ed7a4

FROM ${BASE_IMAGE} AS build

ENV DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=tobi
ARG USER_HOME=/home/$USER_NAME

RUN apt update && apt install -y \
  dnsutils \
  git \
  iputils-ping \
  locales \
  make \
  nmap \
  openssl \
  ssh \
  sudo \
  wget \
  zsh \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && sudo locale-gen \
  && useradd -ms /bin/zsh "$USER_NAME" \
  && echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USER_NAME" \
  && chmod 440 "/etc/sudoers.d/$USER_NAME"

ENV USER=$USER_NAME
ENV HOME=$USER_HOME
USER $USER_NAME
WORKDIR $HOME

RUN git clone https://github.com/this-is-tobi/dotfiles && touch ./.zshrc \
  && ./dotfiles/setup/setup-debian.sh -p "base,devops,secops,go,js" -d -c -l \
  && sudo rm -rf /tmp/* \
  && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/zsh"]

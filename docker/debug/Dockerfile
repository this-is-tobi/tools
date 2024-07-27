FROM docker.io/debian:12 AS build

# Set system env
ENV DEBIAN_FRONTEND=noninteractive
ENV USER=debian
ENV HOME=/home/$USER

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
  && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && sudo locale-gen

RUN useradd -ms /bin/zsh "$USER" \
  && echo "$USER  ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER"

USER $USER
WORKDIR $HOME

RUN git clone https://github.com/this-is-tobi/dotfiles && touch ./.zshrc \
  && ./dotfiles/setup/setup-debian.sh -p "base,devops" -d

ENTRYPOINT ["/bin/zsh"]

ARG BASE_IMAGE=docker.io/debian:13@sha256:fac46bff2e02f51425b6e33b0e1169f55dfb053d83511ca28aa50c09fd5ed7a4

FROM ${BASE_IMAGE} AS build

# Cache-busting marker, rewritten by refresh-images.yml. It has to be copied in
# for the refresh to mean anything: a context file no instruction reads never
# enters a layer's cache key, so every RUN below would be served from the build
# cache and the "refreshed" image would ship the exact same packages.
COPY .refresh /etc/.image-refresh

ENV DEBIAN_FRONTEND=noninteractive
ARG USER_NAME=tobi
ARG USER_HOME=/home/$USER_NAME

RUN apt-get update && apt-get install -y \
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

# Pinned rather than tracking the default branch: an unpinned clone makes the
# image content depend on whatever dotfiles HEAD happens to be at build time,
# so builds aren't reproducible and a bad dotfiles push reaches every image
# built after it. Renovate bumps this through the customManager in renovate.json.
ARG DOTFILES_REF=972015d509ce8af4a886b43f91db4d14af60c356
# The token is mounted as a build secret rather than passed as a build arg, so it
# never reaches an image layer or `docker history`. mise resolves `@latest` through
# the GitHub API, and unauthenticated that is 60 requests/hour shared across every
# runner on the same egress IP - eight images building at once exhaust it and the
# aqua/ubi backends fail with a 403 that mise treats as permanent. The dotfiles
# mise helper retries five times over 50s, which does not outlast a rate-limit
# window. Optional: a local `docker build` without the secret still works, it just
# gets the anonymous limit.

# Purge the package-manager caches in the same layer that fills them - a later
# RUN cannot shrink an earlier layer. These are pure build residue: npm's
# content-addressable store alone runs to gigabytes, and shipping it inflates the
# image, the SBOM (which has a 16 MiB attestation ceiling) and the Trivy scan.
# `go mod download` writes its cache read-only (files 0444, dirs 0555), so a plain
# rm -rf fails there even as the owner - hence the chmod. Grouped with `|| true` so
# only the chmod is forgiving: the surrounding && chain must still fail the build if
# the install above it failed.
RUN --mount=type=secret,id=github_token,mode=0444 \
  export GITHUB_TOKEN="$(cat /run/secrets/github_token 2> /dev/null || true)" \
  && git clone https://github.com/this-is-tobi/dotfiles \
  && git -C dotfiles checkout --quiet "${DOTFILES_REF}" \
  && touch ./.zshrc \
  && ./dotfiles/setup/setup-debian.sh -p "base,devops,secops,go,js" -d -c -l \
  && sudo rm -rf /tmp/* \
  && sudo rm -rf /var/lib/apt/lists/* \
  && { chmod -R u+w "${HOME}/.cache" "${HOME}/.npm/_cacache" \
    "${HOME}/.local/share/mise/downloads" "${HOME}/go/pkg/mod" 2> /dev/null || true; } \
  && rm -rf "${HOME}/.cache" "${HOME}/.npm/_cacache" \
    "${HOME}/.local/share/mise/downloads" "${HOME}/go/pkg/mod"

ENTRYPOINT ["/bin/zsh"]

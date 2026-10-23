# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e

# This image is gh-runner plus the NVIDIA Container Toolkit, so it builds on the
# published gh-runner rather than repeating its Dockerfile, which drifted the
# moment one copy was edited without the other. Pinned by digest like any other
# base: Renovate opens the bump once a new gh-runner is released, and that bump
# is what releases this image with it.
ARG BASE_IMAGE=ghcr.io/this-is-tobi/tools/gh-runner:1.12.8@sha256:1c128808abcd8d3aa7a549cb1039b1a4bc14873b8c456b9e2bb8e8b8baccdece

FROM ${BASE_IMAGE} AS build

# Cache-busting marker, rewritten by refresh-images.yml. It has to be copied in
# for the refresh to mean anything: a context file no instruction reads never
# enters a layer's cache key, so every RUN below would be served from the build
# cache and the "refreshed" image would ship the exact same packages.
COPY .refresh /etc/.image-refresh

# A pipe otherwise reports only its last command, so a failed download feeding
# it would go unnoticed.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Installed as root rather than through sudo: the runner account exists to run
# workflows, and a build step gains nothing from going through it.
USER root

# Install NVIDIA Container Toolkit
# The signing key is the trust root for every package from this repository, so
# it is checked against the fingerprint NVIDIA publishes before apt uses it.
RUN install -d -m 0755 /etc/apt/keyrings \
  && curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey -o /tmp/nvidia-container-toolkit.asc \
  && GNUPG_TMP="$(mktemp -d)" \
  && gpg --homedir "${GNUPG_TMP}" --batch --show-keys --with-colons /tmp/nvidia-container-toolkit.asc \
    | grep -x 'fpr:::::::::C95B321B61E88C1809C4F759DDCAE044F796ECB0:' > /dev/null \
  && gpg --homedir "${GNUPG_TMP}" --batch --dearmor \
    -o /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg /tmp/nvidia-container-toolkit.asc \
  && rm -rf "${GNUPG_TMP}" /tmp/nvidia-container-toolkit.asc \
  && chmod a+r /etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && apt-get update \
  && apt-get install -y nvidia-container-toolkit \
  && rm -rf /var/lib/apt/lists/*

# Back to the account gh-runner ends on, which is the user the image runs as.
USER runner

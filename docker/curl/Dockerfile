ARG BASE_IMAGE=docker.io/alpine:3.21.0

FROM ${BASE_IMAGE} AS build

RUN apk add \
  bash \
  curl \
  jq \
  openssl \
  && rm -rf /var/cache/apk/*

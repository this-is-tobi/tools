ARG BASE_IMAGE=docker.io/curlimages/curl-base:8.11.1

FROM ${BASE_IMAGE} AS build

RUN apk add jq \
  && rm -rf /var/cache/apk/*

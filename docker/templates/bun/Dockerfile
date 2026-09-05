# syntax=docker/dockerfile:1@sha256:ecfaec9ed6d810b56388c508f4121597bfbba70d41a6dfeee4d8cad5f295fc32

# Adjust entrypoints below if your app doesn't use src/index.ts -> dist/index.js.
ARG BUN_IMAGE=docker.io/oven/bun:1.4.2-alpine@sha256:d888c0ae6c86d7866ff10c5aafdd9077b36aee6455b33dd270fb93c0dd5cef6f
ARG BUN_IMAGE_PROD=docker.io/oven/bun:1.4.2-distroless@sha256:1a0c31c7c5f9d193aedf60fe1cebdeb76ac8f6e29f24be8dd8cbd6df72df26ec

# ---- Base: install dependencies (cached separately from source) ----
FROM ${BUN_IMAGE} AS base
# "bun" (uid/gid 1000) is the image's built-in non-root user - installing and
# building as root isn't needed here and only widens what a compromised
# dependency's install/build script could touch.
USER bun
WORKDIR /app
COPY --chown=bun:bun package.json bun.lock* ./
RUN bun install --frozen-lockfile

# ---- Dev stage ----
# Meant to be run with your source bind-mounted over /app for hot reload. If
# your host UID isn't 1000, either chown your project to 1000:1000 or run
# with `docker run --user "$(id -u):$(id -g)" ...` so bun can write to it.
FROM base AS dev
ENV NODE_ENV=development
COPY --chown=bun:bun . .
EXPOSE 3000
CMD ["bun", "--watch", "run", "src/index.ts"]

# ---- Build stage ----
FROM base AS build
# Bundlers (e.g. "bun build") inline process.env.NODE_ENV at build time, so
# this has to be set before building, not just in the prod stage below.
ENV NODE_ENV=production
COPY --chown=bun:bun . .
RUN bun run build \
  && rm -rf node_modules \
  && bun install --frozen-lockfile --production

# ---- Prod stage ----
FROM ${BUN_IMAGE_PROD} AS prod
WORKDIR /app
ENV NODE_ENV=production
COPY --chown=1001:0 --chmod=750 --from=build /app/node_modules ./node_modules
COPY --chown=1001:0 --chmod=750 --from=build /app/dist ./dist
COPY --chown=1001:0 --chmod=640 --from=build /app/package.json ./
USER 1001
EXPOSE 3000
# No shell/wget in this distroless image for a HEALTHCHECK; wire an HTTP
# liveness/readiness probe at the orchestrator level instead.
CMD ["dist/index.js"]

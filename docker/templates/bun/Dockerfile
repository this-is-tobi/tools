# syntax=docker/dockerfile:1

# Adjust entrypoints below if your app doesn't use src/index.ts -> dist/index.js.
ARG BUN_IMAGE=docker.io/oven/bun:1.3.14-alpine@sha256:5acc90a93e91ff07bf72aa90a7c9f0fa189765aec90b47bdbf2152d2196383c0
ARG BUN_IMAGE_PROD=docker.io/oven/bun:1.3.14-distroless@sha256:c28c51287af70bab8e0b66fc4b6a30cfb92a727ebc88045223adc9f4c9d09307

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

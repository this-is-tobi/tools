# syntax=docker/dockerfile:1

# Adjust entrypoints below if your app doesn't use src/index.ts -> dist/index.js.
ARG BUN_IMAGE=docker.io/oven/bun:1.3.14-alpine
ARG BUN_IMAGE_PROD=docker.io/oven/bun:1.3.14-distroless

# ---- Base: install dependencies (cached separately from source) ----
FROM ${BUN_IMAGE} AS base
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# ---- Dev stage ----
# Meant to be run with your source bind-mounted over /app for hot reload.
FROM base AS dev
ENV NODE_ENV=development
COPY . .
EXPOSE 3000
CMD ["bun", "--watch", "run", "src/index.ts"]

# ---- Build stage ----
FROM base AS build
# Bundlers (e.g. "bun build") inline process.env.NODE_ENV at build time, so
# this has to be set before building, not just in the prod stage below.
ENV NODE_ENV=production
COPY . .
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

# syntax=docker/dockerfile:1

# Adjust the build command / output dir below to match your frontend
# toolchain if it isn't a plain Vite-style "bun run build" -> dist.
ARG BUN_IMAGE=docker.io/oven/bun:1.3.14-alpine
ARG NGINX_IMAGE=docker.io/nginxinc/nginx-unprivileged:1.31.2-alpine

# ---- Base: install dependencies (cached separately from source) ----
FROM ${BUN_IMAGE} AS base
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile

# ---- Dev stage ----
# Meant to be run with your source bind-mounted over /app for hot reload.
# "--host" is needed for most dev servers (e.g. Vite) to be reachable from
# outside the container.
FROM base AS dev
COPY . .
EXPOSE 5173
CMD ["bun", "run", "dev", "--", "--host"]

# ---- Build stage ----
FROM base AS build
# Some bundlers inline process.env.NODE_ENV at build time, so this has to be
# set before building, not just at runtime.
ENV NODE_ENV=production
COPY . .
RUN bun run build

# ---- Prod stage ----
FROM ${NGINX_IMAGE} AS prod

# Backend proxied at /api (see default.conf.template). Defaults to a
# harmless loopback so the container still starts if /api isn't used.
ENV SERVER=127.0.0.1:0
USER 0
COPY --chown=1001:0 --chmod=770 --from=build /app/dist /usr/share/nginx/html/
# --chmod is also applied to the auto-created /etc/nginx/templates dir, so it needs the execute bit to stay traversable.
COPY --chown=1001:0 --chmod=750 ./default.conf.template /etc/nginx/templates/default.conf.template
COPY --chown=1001:0 --chmod=750 ./entrypoint.sh /docker-entrypoint.d/90-runtime-env.sh
USER 1001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O- http://127.0.0.1:8080/healthz || exit 1

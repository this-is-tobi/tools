# syntax=docker/dockerfile:1

# Adjust the build command / output dir below to match your frontend
# toolchain if it isn't a plain Vite-style "bun run build" -> dist.
ARG BUN_IMAGE=docker.io/oven/bun:1.4.0-alpine@sha256:07235578f79ef8c6f97d94aee7938e76f5cdba5f21ae5dbfdd3d3d38058437eb
ARG NGINX_IMAGE=docker.io/nginxinc/nginx-unprivileged:1.31.4-alpine@sha256:c3fed6436b61d2bf2201ec032c35c000871f7ed062dea5d586bc6bf4d0fdd140

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
# Meant to be run with your source bind-mounted over /app for hot reload.
# "--host" is needed for most dev servers (e.g. Vite) to be reachable from
# outside the container. If your host UID isn't 1000, either chown your
# project to 1000:1000 or run with `docker run --user "$(id -u):$(id -g)" ...`
# so bun can write to it.
FROM base AS dev
COPY --chown=bun:bun . .
EXPOSE 5173
CMD ["bun", "run", "dev", "--", "--host"]

# ---- Build stage ----
FROM base AS build
# Some bundlers inline process.env.NODE_ENV at build time, so this has to be
# set before building, not just at runtime.
ENV NODE_ENV=production
COPY --chown=bun:bun . .
RUN bun run build

# ---- Prod stage ----
FROM ${NGINX_IMAGE} AS prod

# Backend proxied at /api (see default.conf.template). Defaults to a
# harmless placeholder so the container still starts if /api isn't used -
# port 0 looks equally harmless but nginx rejects it as an invalid upstream
# port at config-load time and refuses to start at all.
ENV SERVER=127.0.0.1:1
# Must stay >1024 - the image runs as non-root, which can't bind a privileged
# port. Substituted into default.conf.template's "listen" directive by
# nginx's own envsubst-on-templates entrypoint step, same mechanism as SERVER.
ENV PORT=8080
USER 0
COPY --chown=1001:0 --chmod=770 --from=build /app/dist /usr/share/nginx/html/
# --chmod is also applied to the auto-created /etc/nginx/templates dir, so it needs the execute bit to stay traversable.
COPY --chown=1001:0 --chmod=750 ./default.conf.template /etc/nginx/templates/default.conf.template
COPY --chown=1001:0 --chmod=750 ./entrypoint.sh /docker-entrypoint.d/90-runtime-env.sh
USER 1001
EXPOSE ${PORT}
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O- http://127.0.0.1:${PORT}/healthz || exit 1

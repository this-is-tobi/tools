#!/usr/bin/env bash
# Smoke test for the `backup` image.
#
# The image ships a thorough check of its own tooling as its Docker HEALTHCHECK;
# running it here turns that into a build-time gate instead of something only
# observed once a container is live. Keeping the assertions there rather than
# duplicating them here means the healthcheck and the test cannot disagree.
. "$(dirname "$0")/lib.sh"

echo "backup: bundled healthcheck"
if "${HOME}/scripts/healthcheck.sh"; then
  printf '  ok       healthcheck.sh\n'
else
  printf '  FAILED   healthcheck.sh\n'
  FAILURES=$((FAILURES + 1))
fi

echo "backup: mise inventory"
probe_mise_shims optional

echo "backup: user"
require_non_root

# Each script, against a local destination with stubs ahead of the real tools:
# it completes and leaves its backup there, and a step that fails fails the job
# through its ERR trap instead of ending in "Backup completed". The snapshot
# tools write a file and the dump tools a few bytes; FAIL_DUMP makes a dump
# fail, FAIL_COPY makes rclone's `copyto` fail, and rclone hands every other
# command to the real one.
echo "backup: a backup completes, a failed step fails the job"
work=$(mktemp -d)
mkdir -p "$work/bin"
real_rclone=$(command -v rclone)
stub() { # stub <name> <body>
  printf '#!/bin/sh\n%s\n' "$2" >"$work/bin/$1"
  chmod +x "$work/bin/$1"
}
stub vault 'if [ "$1" = status ]; then echo "{}"; exit 0; fi
for a; do last=$a; done; echo snapshot >"$last"'
stub etcdctl 'for a; do last=$a; done; echo snapshot >"$last"'
for dump in pg_dump mariadb-dump mongodump; do stub "$dump" 'echo dump; [ -z "$FAIL_DUMP" ]'; done
stub rclone "[ \"\$1\" = copyto ] && [ -n \"\$FAIL_COPY\" ] && exit 1; exec $real_rclone \"\$@\""
# run_backup <script> <VAR=value>...: runs it into a new destination, and sets
# out, rc and dest.
run_backup() {
  local script="$1"
  shift
  dest=$(mktemp -d "$work/dest.XXXXXX")
  out=$(cd "$work" && env PATH="$work/bin:$PATH" LOCAL_PATH="$dest" "$@" "${HOME}/scripts/$script" 2>&1)
  rc=$?
}
verdict() { # verdict <label> <0 when as expected>
  if [ "$2" -eq 0 ]; then printf '  ok       %s\n' "$1"; else
    printf '  FAILED   %s (exit %s)\n' "$1" "$rc"
    FAILURES=$((FAILURES + 1))
  fi
}
completes() { # completes <label> <script> <VAR=value>...
  local label="$1"
  shift
  run_backup "$@"
  [ "$rc" -eq 0 ] && grep -q 'Backup completed' <<<"$out" && [ -n "$(ls -A "$dest")" ]
  verdict "$label" $?
}
stops() { # stops <label> <script> <VAR=value>...
  local label="$1"
  shift
  run_backup "$@"
  [ "$rc" -ne 0 ] && grep -q 'Backup failed at line' <<<"$out" && ! grep -q 'Backup completed' <<<"$out"
  verdict "$label" $?
}
vault=(vault-backup.sh VAULT_ADDR=http://vault:8200 VAULT_TOKEN=x)
etcd=(etcd-backup.sh ETCD_ENDPOINTS=http://etcd:2379)
db=(DB_HOST=db DB_PORT=5432 DB_NAME=app DB_USER=app DB_PASS=x)
completes "vault: completes" "${vault[@]}"
stops "vault: a failed upload fails the job" "${vault[@]}" FAIL_COPY=1
completes "etcd: completes" "${etcd[@]}"
stops "etcd: a failed upload fails the job" "${etcd[@]}" FAIL_COPY=1
for db_type in postgres mariadb mongodb; do
  completes "$db_type: completes" "$db_type-backup.sh" "${db[@]}"
  stops "$db_type: a failed dump fails the job" "$db_type-backup.sh" "${db[@]}" FAIL_DUMP=1
done
rm -rf "$work"

report

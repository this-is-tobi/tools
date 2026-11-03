#!/usr/bin/env bash
# Smoke test for the `gh-runner` image the way a hardened pod runs it: non-root,
# no privilege escalation, every capability dropped and a read-only root
# filesystem, with writable volumes only where docs/04-docker.md says a pod must
# provide them. ci.yml starts this with exactly those `docker run` flags, so a
# path the docs call sufficient that is not shows up here as a failure.
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-runner.sh"

# The volumes the pod mounts; keep in step with docs/04-docker.md and the
# RUN_ARGS of the hardened test job in ci.yml.
WRITABLE_PATHS=(
  /tmp
  "${HOME}/_work"
  "${HOME}/_diag"
  "${HOME}/.cache"
  "${HOME}/.config"
  "${HOME}/.local"
  "${HOME}/.cargo/registry"
  "${HOME}/.cargo/git"
  "${HOME}/.npm"
  "${HOME}/.yarn"
  "${HOME}/.bun"
  "${HOME}/go"
  "${HOME}/.docker"
  "${HOME}/.kube"
  "${HOME}/.sigstore"
  "${HOME}/.terraform.d"
  "${HOME}/.ansible"
  "${HOME}/.krew"
)

writable() {
  local probe="$1/.probe.$$"
  : > "$probe" 2> /dev/null && unlink "$probe"
}

not_writable() {
  ! writable "$1"
}

no_new_privs() {
  grep -q '^NoNewPrivs:[[:space:]]*1' /proc/self/status
}

# The wrapper has to explain the refusal, not just fail: that message is all a
# job author sees.
sudo_explains() {
  local out
  if out=$(sudo -n true 2>&1); then
    return 1
  fi
  case "$out" in
    *"does not allow privilege escalation"*) return 0 ;;
    *) return 1 ;;
  esac
}

# run.sh copies run-helper.sh.template over run-helper.sh on every start, which
# cannot work on a read-only root; the image bakes the file so the runner starts
# anyway.
runner_starts() {
  local out
  out=$(cd "${HOME}" && timeout 60 ./run.sh --version 2>&1) || return 1
  case "$out" in
    *[0-9].[0-9]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Runs a command in a scratch directory under /tmp, which every pod mounts.
in_scratch() {
  local dir rc
  dir=$(mktemp -d) || return 1
  (cd "$dir" && "$@")
  rc=$?
  rm -rf "$dir"
  return "$rc"
}

go_builds() {
  go mod init probe > /dev/null 2>&1 \
    && printf 'package main\nfunc main() {}\n' > main.go \
    && go build ./...
}

cargo_builds() {
  cargo new --bin app > /dev/null 2>&1 && (cd app && cargo build)
}

git_writes_global_config() {
  git config --global user.name probe && [ "$(git config --global user.name)" = probe ]
}

echo "gh-runner (hardened): the pod's security context"
require_non_root
require_run no-new-privs no_new_privs
# The runner account owns its home directory, so only a read-only root
# filesystem can make it unwritable.
require_run read-only-root-filesystem not_writable "${HOME}"
require_run sudo-explains-the-refusal sudo_explains
require_run runner-starts runner_starts

echo "gh-runner (hardened): the volumes a pod provides are enough"
for path in "${WRITABLE_PATHS[@]}"; do
  require_run "writable ${path}" writable "$path"
done

echo "gh-runner (hardened): what a job writes first"
require_run git-global-config git_writes_global_config
require_run go-build in_scratch go_builds
require_run cargo-build in_scratch cargo_builds
require_run npm-init in_scratch npm init -y
require_run uv-venv in_scratch uv venv venv
require_run helm-template in_scratch bash -c 'helm create chart > /dev/null && helm template probe chart'
require_run kubectl-config kubectl config set-cluster probe --server=https://127.0.0.1:1
require_run docker-buildx-remote docker buildx create --name "probe-$$" --driver remote tcp://127.0.0.1:1
require_run gh-config gh config set editor vim
require_run terraform-version terraform version
require_run ansible-ping "${HOME}/.venv/bin/ansible" localhost -m ping

check_runner_common gh-runner
check_runner_build_tools gh-runner

report

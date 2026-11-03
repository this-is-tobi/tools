#!/usr/bin/env bash
# Checks shared by the three CI runner images (act-runner, gh-runner,
# gh-runner-gpu), which install the same toolchain from the same Dockerfile
# blocks.
#
# The declared list below is a *contract*, not an inventory: these are the tools
# a workflow running on these images is entitled to assume, so dropping one
# should fail here and force a deliberate decision. Everything else mise
# installs is covered automatically: probe_mise_config_installed checks every
# tool pinned in the image's mise.toml, and probe_mise_shims every binary those
# tools expose - adding a tool to mise.toml needs no edit here.

# A compiler on PATH is not a working toolchain: building and running a trivial
# program also needs the C library headers and the linker.
compiles_c() {
  local dir ok=1
  dir=$(mktemp -d) || return 1
  printf 'int main(void){return 0;}' > "${dir}/t.c"
  if gcc "${dir}/t.c" -o "${dir}/t" && "${dir}/t"; then
    ok=0
  fi
  rm -rf "$dir"
  return "$ok"
}

# What the apt layer of act-runner and gh-runner adds for jobs that cannot
# install packages themselves (no sudo where the pod forbids privilege
# escalation). Kept apart from check_runner_common because gh-runner-gpu is
# built on the *published* gh-runner: it only has these once the gh-runner pin in
# its Dockerfile does, so its test calls this after that bump.
check_runner_build_tools() {
  local image="$1"

  echo "${image}: build and archive tools (apt)"
  for bin in bzip2 g++ gcc git-lfs pkg-config xz zstd; do
    require_cmd "$bin"
  done
  require_run gcc-compile compiles_c
}

check_runner_common() {
  local image="$1"

  echo "${image}: system tools (apt)"
  for bin in jq make tar unzip; do
    require_cmd "$bin"
  done

  echo "${image}: container tooling"
  require_cmd docker

  echo "${image}: language runtimes"
  # The reason to reach for these images at all - a workflow that cannot find
  # its runtime has nothing to fall back on.
  for bin in node go uv; do
    require_cmd "$bin"
  done

  echo "${image}: core ci tooling"
  for bin in gh helm kubectl trivy; do
    require_cmd "$bin"
  done

  echo "${image}: python tooling"
  require_file "${HOME}/.venv/bin/ansible"
  require_run ansible "${HOME}/.venv/bin/ansible" --version

  echo "${image}: mise inventory"
  # Enumerated from the image, so this tracks mise.toml automatically.
  require_run mise mise --version
  probe_mise_config_installed
  probe_mise_shims
  probe_mise_consistency

  echo "${image}: execution"
  # probe_mise_shims proves every binary links; these prove a few actually run.
  require_run node node --version
  require_run go go version
  require_run kubectl kubectl version --client

  echo "${image}: user"
  require_non_root
}

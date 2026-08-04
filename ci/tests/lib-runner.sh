#!/usr/bin/env bash
# Checks shared by the three CI runner images (act-runner, gh-runner,
# gh-runner-gpu), which install the same toolchain from the same Dockerfile
# blocks.
#
# The declared list below is a *contract*, not an inventory: these are the tools
# a workflow running on these images is entitled to assume, so dropping one
# should fail here and force a deliberate decision. Everything else mise
# installs is covered automatically by probe_mise_shims - adding a tool to the
# Dockerfile needs no edit here.

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
  # Enumerated from the image, so this tracks the Dockerfile automatically.
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

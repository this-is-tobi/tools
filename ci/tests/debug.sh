#!/usr/bin/env bash
# Smoke test for the `debug` image.
#
# Built with the dotfiles `base,devops,secops` profiles in lite mode with
# DEVOPS_CATEGORIES=k8s.
#
# The declared checks below are a contract - the tools this image exists to
# provide. The rest of what the dotfiles setup scripts install is covered
# automatically by probe_mise_shims, so a tool added there needs no edit here.
. "$(dirname "$0")/lib.sh"

echo "debug: system tools (apt)"
for bin in git ssh openssl zsh; do
  require_cmd "$bin"
done

echo "debug: kubernetes tooling"
for bin in helm kubectl; do
  require_cmd "$bin"
done

echo "debug: mise inventory"
probe_mise_shims
probe_mise_consistency

echo "debug: execution"
require_run kubectl kubectl version --client
require_run helm helm version

echo "debug: user"
require_non_root

report

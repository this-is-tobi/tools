#!/usr/bin/env bash
# Smoke test for the `dev-lite` image.
#
# Built with the dotfiles `base,devops,secops,go,js` profiles in lite mode.
#
# The declared checks below are a contract - the tools this image exists to
# provide. The rest of what the dotfiles setup scripts install is covered
# automatically by probe_mise_shims, so a tool added there needs no edit here.
. "$(dirname "$0")/lib.sh"

echo "dev-lite: system tools (apt)"
for bin in git ssh openssl zsh; do
  require_cmd "$bin"
done

echo "dev-lite: kubernetes tooling"
for bin in helm kubectl; do
  require_cmd "$bin"
done

echo "dev-lite: language runtimes"
# The go/js profiles are the reason these images differ from debug.
for bin in go node; do
  require_cmd "$bin"
done

echo "dev-lite: mise inventory"
probe_mise_shims
probe_mise_consistency

echo "dev-lite: execution"
require_run kubectl kubectl version --client
require_run helm helm version

echo "dev-lite: user"
require_non_root

report

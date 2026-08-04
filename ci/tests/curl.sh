#!/usr/bin/env bash
# Smoke test for the `curl` image.
#
# Everything here comes from a single apk line, so the declared list is the
# whole image - there is no separate inventory to drift.
. "$(dirname "$0")/lib.sh"

echo "curl: tools"
for bin in bash curl jq openssl wget yq; do
  require_cmd "$bin"
done

echo "curl: execution"
require_run curl curl --version
require_run jq jq --version
require_run yq yq --version
require_run openssl openssl version

echo "curl: mise inventory"
probe_mise_shims optional

echo "curl: user"
require_non_root

report

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

report

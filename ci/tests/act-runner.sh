#!/usr/bin/env bash
# Smoke test for the `act-runner` image - the shared runner toolchain plus the
# extras its own apt layer adds.
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-runner.sh"

check_runner_common act-runner

echo "act-runner: additional system tools (apt)"
for bin in curl gpg sudo; do
  require_cmd "$bin"
done

echo "act-runner: privilege escalation"
# Workflow steps routinely call sudo, so passwordless sudo has to keep working
# now that the image no longer runs as root.
require_run sudo sudo -n true

report

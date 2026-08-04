#!/usr/bin/env bash
# Smoke test for the `gh-runner` image.
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-runner.sh"

check_runner_common gh-runner

report

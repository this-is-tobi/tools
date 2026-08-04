#!/usr/bin/env bash
# Smoke test for the `gh-runner-gpu` image - the gh-runner toolchain plus the
# NVIDIA Container Toolkit.
. "$(dirname "$0")/lib.sh"
. "$(dirname "$0")/lib-runner.sh"

check_runner_common gh-runner-gpu

echo "gh-runner-gpu: nvidia container toolkit"
# No GPU is present on the CI runner, so this only asserts the toolkit was
# installed and is runnable - not that it can talk to a device.
require_cmd nvidia-ctk
require_run nvidia-ctk nvidia-ctk --version

report

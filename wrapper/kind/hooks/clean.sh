#!/bin/bash

# Removes the application from the kind cluster, keeping the cluster itself and
# its ingress controller. Called from the project root by './kind/run.sh clean'.
#
#   KUBE_CONTEXT       kubectl / helm context of the cluster.
#   KIND_CLUSTER_NAME  Name of the cluster (kind commands target it by default).
#   PROJECT_ROOT       Absolute path of the project.

set -euo pipefail

HOOKS_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"

echo "Nothing to clean yet: edit ${HOOKS_DIR}/clean.sh to uninstall the application."

# Example with a helm release:
#
# helm uninstall my-app --kube-context "$KUBE_CONTEXT"

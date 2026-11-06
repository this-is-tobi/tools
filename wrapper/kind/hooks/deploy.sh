#!/bin/bash

# Deploys the application into the kind cluster.
# Called from the project root by './kind/run.sh deploy', 'dev' and 'prod'.
#
#   $1                 Mode: 'dev' or 'prod' (matches env/helm-values.<mode>.yaml).
#   IMAGE_TAG          Tag given with -t, empty when there is none.
#   KUBE_CONTEXT       kubectl / helm context of the cluster.
#   KIND_CLUSTER_NAME  Name of the cluster (kind commands target it by default).
#   PROJECT_ROOT       Absolute path of the project.

set -euo pipefail

MODE="$1"
HOOKS_DIR="$(cd -- "$(dirname "$0")" > /dev/null 2>&1; pwd -P)"

echo "Nothing to deploy yet: edit ${HOOKS_DIR}/deploy.sh to install the application (${MODE} mode)."

# Example with a helm chart:
#
# helm upgrade --install my-app "$PROJECT_ROOT/helm" \
#   --kube-context "$KUBE_CONTEXT" \
#   --values "$HOOKS_DIR/../env/helm-values.${MODE}.yaml" \
#   ${IMAGE_TAG:+--set image.tag="$IMAGE_TAG"}

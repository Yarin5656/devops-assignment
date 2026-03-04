#!/usr/bin/env bash
# =============================================================================
# deploy-production.sh – Deploy a specific image tag to production
#
# Usage:
#   ./scripts/deploy-production.sh <IMAGE_TAG>
#   make deploy-production IMAGE_TAG=1.2.3-abc1234
#
# Safety gate: asks for confirmation before applying to production.
# =============================================================================
set -euo pipefail

IMAGE_TAG="${1:?Usage: $0 <IMAGE_TAG>}"
CLUSTER_NAME="url-shortener-local"
REGISTRY="localhost:5001"
IMAGE_NAME="url-shortener"
NAMESPACE="url-shortener-production"
CONTEXT="kind-${CLUSTER_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  PRODUCTION DEPLOY                                               │"
echo "│  Image: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "│  Namespace: ${NAMESPACE}"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""
read -r -p "Proceed with production deploy? [yes/No] " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Record current image for potential rollback
CURRENT_IMAGE=$(kubectl get deployment/url-shortener \
    --context "${CONTEXT}" \
    -n "${NAMESPACE}" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "none")
echo "Current production image: ${CURRENT_IMAGE}"

# Push to local registry (image must already be built)
echo "--- Pushing image to local registry..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || \
  docker tag "${IMAGE_NAME}:local"      "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Update kustomize overlay
echo "--- Updating kustomize image tag..."
cd "${REPO_ROOT}/k8s/overlays/production"
kustomize edit set image \
    "localhost:5001/${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
cd "${REPO_ROOT}"

# Apply
echo "--- Applying manifests..."
kustomize build k8s/overlays/production | kubectl apply --context "${CONTEXT}" -f -

# Wait for rollout (auto-rollback on failure)
echo "--- Waiting for rollout (180s timeout)..."
if ! kubectl rollout status deployment/url-shortener \
        --context "${CONTEXT}" \
        -n "${NAMESPACE}" \
        --timeout=180s; then
    echo ""
    echo "❌ Rollout failed! Auto-rolling back..."
    kubectl rollout undo deployment/url-shortener \
        --context "${CONTEXT}" \
        -n "${NAMESPACE}"
    kubectl rollout status deployment/url-shortener \
        --context "${CONTEXT}" \
        -n "${NAMESPACE}" \
        --timeout=120s
    echo "Rollback complete. Previous image: ${CURRENT_IMAGE}"
    exit 1
fi

echo ""
echo "✅ Production deploy complete: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

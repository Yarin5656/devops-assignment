#!/usr/bin/env bash
# =============================================================================
# deploy-staging.sh – Build, push, and deploy to local staging namespace
#
# Usage:
#   ./scripts/deploy-staging.sh [IMAGE_TAG]
#   make deploy-staging IMAGE_TAG=1.2.3-abc1234
# =============================================================================
set -euo pipefail

IMAGE_TAG="${1:-local}"
CLUSTER_NAME="url-shortener-local"
REGISTRY="localhost:5001"
IMAGE_NAME="url-shortener"
NAMESPACE="url-shortener-staging"
CONTEXT="kind-${CLUSTER_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> Deploying url-shortener:${IMAGE_TAG} to staging..."

# Tag and push to local registry
echo "--- Tagging and pushing image..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || \
  docker tag "${IMAGE_NAME}:local"      "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
docker push "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Update kustomize overlay image tag
echo "--- Updating kustomize image tag..."
cd "${REPO_ROOT}/k8s/overlays/staging"
kustomize edit set image \
    "localhost:5001/${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
cd "${REPO_ROOT}"

# Apply manifests
echo "--- Applying manifests..."
kustomize build k8s/overlays/staging | kubectl apply --context "${CONTEXT}" -f -

# Wait for rollout
echo "--- Waiting for rollout (120s timeout)..."
kubectl rollout status deployment/url-shortener \
    --context "${CONTEXT}" \
    -n "${NAMESPACE}" \
    --timeout=120s

echo ""
echo "✅ Staging deploy complete: ${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "   Port-forward to test:"
echo "     kubectl port-forward svc/url-shortener 8080:80 -n ${NAMESPACE} --context ${CONTEXT}"
echo "   Then: curl http://localhost:8080/healthz"

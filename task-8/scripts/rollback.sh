#!/usr/bin/env bash
# =============================================================================
# rollback.sh – Roll back a deployment to the previous revision
#
# Usage:
#   ./scripts/rollback.sh staging          # rollback staging
#   ./scripts/rollback.sh production       # rollback production (with confirmation)
#   ./scripts/rollback.sh staging 3        # rollback to specific revision
# =============================================================================
set -euo pipefail

ENV="${1:?Usage: $0 <staging|production> [revision]}"
REVISION="${2:-}"
CLUSTER_NAME="url-shortener-local"
CONTEXT="kind-${CLUSTER_NAME}"

case "$ENV" in
    staging)    NAMESPACE="url-shortener-staging" ;;
    production) NAMESPACE="url-shortener-production" ;;
    *)
        echo "ERROR: environment must be 'staging' or 'production'"
        exit 1 ;;
esac

if [[ "$ENV" == "production" ]]; then
    echo ""
    echo "WARNING: Rolling back PRODUCTION deployment!"
    read -r -p "Confirm rollback to previous revision? [yes/No] " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Aborted."
        exit 0
    fi
fi

echo "==> Rollout history for ${NAMESPACE}:"
kubectl rollout history deployment/url-shortener \
    --context "${CONTEXT}" \
    -n "${NAMESPACE}"
echo ""

if [[ -n "$REVISION" ]]; then
    echo "==> Rolling back to revision ${REVISION}..."
    kubectl rollout undo deployment/url-shortener \
        --context "${CONTEXT}" \
        -n "${NAMESPACE}" \
        --to-revision="${REVISION}"
else
    echo "==> Rolling back to previous revision..."
    kubectl rollout undo deployment/url-shortener \
        --context "${CONTEXT}" \
        -n "${NAMESPACE}"
fi

echo "==> Waiting for rollback to complete..."
kubectl rollout status deployment/url-shortener \
    --context "${CONTEXT}" \
    -n "${NAMESPACE}" \
    --timeout=120s

echo ""
echo "✅ Rollback complete."
kubectl get deployment/url-shortener \
    --context "${CONTEXT}" \
    -n "${NAMESPACE}" \
    -o jsonpath='Current image: {.spec.template.spec.containers[0].image}{"\n"}'

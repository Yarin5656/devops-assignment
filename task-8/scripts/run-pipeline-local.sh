#!/usr/bin/env bash
# =============================================================================
# run-pipeline-local.sh – Simulate the CI/CD pipeline locally without Jenkins
#
# Stages: lint → test → security-scan → build → (optional) deploy-staging
#
# Usage:
#   ./scripts/run-pipeline-local.sh           # all stages
#   ./scripts/run-pipeline-local.sh --skip-scan  # skip Trivy (faster)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKIP_SCAN=false
DEPLOY=false

for arg in "$@"; do
    case "$arg" in
        --skip-scan) SKIP_SCAN=true ;;
        --deploy)    DEPLOY=true ;;
    esac
done

log() { echo ""; echo "══════════════════════════════════════════════════"; echo "  $1"; echo "══════════════════════════════════════════════════"; }

GIT_SHA=$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "local")
IMAGE_TAG="local-${GIT_SHA}"

# ---------------------------------------------------------------------------
log "STAGE: Lint"
cd "$REPO_ROOT/app"
pip install --quiet ruff
ruff check .
ruff format --check .
echo "✅ Lint passed"

# ---------------------------------------------------------------------------
log "STAGE: Unit Tests (coverage >= 80%)"
pip install --quiet -r requirements.txt
pytest tests/ -v \
    --cov=. \
    --cov-report=term-missing \
    --cov-fail-under=80
echo "✅ Tests passed"

# ---------------------------------------------------------------------------
cd "$REPO_ROOT"
log "STAGE: Build Docker Image"
docker build -t "url-shortener:${IMAGE_TAG}" .
echo "✅ Image built: url-shortener:${IMAGE_TAG}"

# ---------------------------------------------------------------------------
if [[ "$SKIP_SCAN" == "false" ]]; then
    log "STAGE: Security Scan (Trivy)"
    if ! command -v trivy &>/dev/null; then
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
            | sh -s -- -b /usr/local/bin
    fi
    trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed \
        "url-shortener:${IMAGE_TAG}"
    echo "✅ Security scan passed"
else
    echo "⚠️  Security scan SKIPPED (--skip-scan)"
fi

# ---------------------------------------------------------------------------
if [[ "$DEPLOY" == "true" ]]; then
    log "STAGE: Deploy → Staging"
    "$SCRIPT_DIR/deploy-staging.sh" "${IMAGE_TAG}"
    echo "✅ Staging deploy complete"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "  ✅ Local pipeline complete: url-shortener:${IMAGE_TAG}"
echo "══════════════════════════════════════════════════"

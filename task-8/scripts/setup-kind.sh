#!/usr/bin/env bash
# =============================================================================
# setup-kind.sh – Create a local kind cluster with a local container registry
#
# Prerequisites: kind, kubectl, docker
# Tested on: Linux, macOS, Windows Git Bash + Docker Desktop
#
# What it does:
#   1. Starts a local Docker registry on localhost:5001
#   2. Creates a kind cluster using infra/kind/cluster.yaml
#   3. Connects the registry to the kind network
#   4. Applies the registry ConfigMap so nodes can discover it
#   5. Creates staging + production namespaces
#
# After this script, push images with:
#   docker tag url-shortener:local localhost:5001/url-shortener:latest
#   docker push localhost:5001/url-shortener:latest
# =============================================================================
set -euo pipefail

CLUSTER_NAME="url-shortener-local"
REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5001"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> [1/5] Starting local registry on localhost:${REGISTRY_PORT}..."
if ! docker inspect "${REGISTRY_NAME}" &>/dev/null; then
    docker run -d \
        --restart=always \
        --name "${REGISTRY_NAME}" \
        -p "127.0.0.1:${REGISTRY_PORT}:5000" \
        registry:2
    echo "    Registry started."
else
    echo "    Registry already running."
fi

echo "==> [2/5] Creating kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "    Cluster '${CLUSTER_NAME}' already exists – skipping create."
else
    kind create cluster \
        --name "${CLUSTER_NAME}" \
        --config "${REPO_ROOT}/infra/kind/cluster.yaml" \
        --wait 120s
    echo "    Cluster created."
fi

echo "==> [3/5] Connecting registry to kind network..."
REGISTRY_NETWORK="kind"
if ! docker network inspect "${REGISTRY_NETWORK}" \
      --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "${REGISTRY_NAME}"; then
    docker network connect "${REGISTRY_NETWORK}" "${REGISTRY_NAME}" 2>/dev/null || true
    echo "    Connected."
else
    echo "    Already connected."
fi

echo "==> [4/5] Applying local registry ConfigMap to cluster..."
kubectl apply --context "kind-${CLUSTER_NAME}" -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "==> [5/5] Creating application namespaces..."
for NS in url-shortener-staging url-shortener-production; do
    kubectl create namespace "$NS" \
        --context "kind-${CLUSTER_NAME}" \
        --dry-run=client -o yaml | kubectl apply --context "kind-${CLUSTER_NAME}" -f -
    echo "    Namespace '${NS}' ready."
done

echo ""
echo "✅ kind cluster '${CLUSTER_NAME}' is ready!"
echo ""
echo "   kubectl context: kind-${CLUSTER_NAME}"
echo "   Local registry:  localhost:${REGISTRY_PORT}"
echo ""
echo "   Push an image:"
echo "     docker tag url-shortener:local localhost:${REGISTRY_PORT}/url-shortener:latest"
echo "     docker push localhost:${REGISTRY_PORT}/url-shortener:latest"
echo ""
echo "   Deploy staging:"
echo "     make deploy-staging IMAGE_TAG=latest"
echo ""
echo "   Get kubeconfig (for CI secrets):"
echo "     kind get kubeconfig --name ${CLUSTER_NAME} | base64 -w0"

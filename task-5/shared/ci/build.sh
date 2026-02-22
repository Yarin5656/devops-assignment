#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="${1:?usage: build.sh <service_dir> <tag>}"
TAG="${2:?usage: build.sh <service_dir> <tag>}"
SERVICE_NAME="$(basename "${SERVICE_DIR}")"

REGISTRY_PROVIDER="${REGISTRY_PROVIDER:-dockerhub}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-local}"
PUSH_IMAGES="${PUSH_IMAGES:-false}"

IMAGE_REPO="${REGISTRY_NAMESPACE}/${SERVICE_NAME}"
if [[ -n "${DOCKER_REGISTRY}" ]]; then
  IMAGE_REPO="${DOCKER_REGISTRY}/${IMAGE_REPO}"
fi
IMAGE_TAG="${IMAGE_REPO}:${TAG}"

docker build -t "${IMAGE_TAG}" "${SERVICE_DIR}"

if [[ "${PUSH_IMAGES}" != "true" ]]; then
  echo "Skipping push for ${IMAGE_TAG}. Set PUSH_IMAGES=true to enable."
  exit 0
fi

case "${REGISTRY_PROVIDER}" in
  dockerhub)
    : "${DOCKER_USERNAME:?Missing DOCKER_USERNAME env var}"
    : "${DOCKER_PASSWORD:?Missing DOCKER_PASSWORD env var}"
    if [[ -n "${DOCKER_REGISTRY}" ]]; then
      echo "${DOCKER_PASSWORD}" | docker login "${DOCKER_REGISTRY}" -u "${DOCKER_USERNAME}" --password-stdin
    else
      echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
    fi
    ;;
  ecr)
    : "${AWS_REGION:?Missing AWS_REGION env var}"
    : "${AWS_ACCOUNT_ID:?Missing AWS_ACCOUNT_ID env var}"
    aws ecr get-login-password --region "${AWS_REGION}" | \
      docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ;;
  *)
    echo "Unsupported REGISTRY_PROVIDER: ${REGISTRY_PROVIDER}" >&2
    exit 1
    ;;
esac

docker push "${IMAGE_TAG}"

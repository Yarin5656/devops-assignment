#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="${1:?usage: lint.sh <service_dir>}"
SERVICE_NAME="$(basename "${SERVICE_DIR}")"

cd "${SERVICE_DIR}"

case "${SERVICE_NAME}" in
  user-service)
    npm install
    npm run lint
    ;;
  transaction-service)
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt -r requirements-dev.txt
    flake8 .
    ;;
  notification-service)
    export PATH="${PATH}:$(go env GOPATH)/bin"
    if ! command -v golangci-lint >/dev/null 2>&1; then
      go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    fi
    golangci-lint run ./...
    ;;
  *)
    echo "Unsupported service: ${SERVICE_NAME}" >&2
    exit 1
    ;;
esac

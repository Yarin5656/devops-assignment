#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="${1:?usage: test.sh <service_dir>}"
SERVICE_NAME="$(basename "${SERVICE_DIR}")"

cd "${SERVICE_DIR}"
mkdir -p test-results coverage

case "${SERVICE_NAME}" in
  user-service)
    npm install
    npm test
    ;;
  transaction-service)
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt -r requirements-dev.txt
    pytest \
      --junitxml=test-results/junit.xml \
      --cov=app \
      --cov-report=xml:coverage/coverage.xml
    ;;
  notification-service)
    export PATH="${PATH}:$(go env GOPATH)/bin"
    go test ./... -coverprofile=coverage/coverage.out
    go test -v ./... 2>&1 | tee test-results/go-test.txt
    if ! command -v go-junit-report >/dev/null 2>&1; then
      go install github.com/jstemmer/go-junit-report/v2@latest || true
    fi
    if command -v go-junit-report >/dev/null 2>&1; then
      go-junit-report < test-results/go-test.txt > test-results/junit.xml || true
    fi
    ;;
  *)
    echo "Unsupported service: ${SERVICE_NAME}" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

SERVICE_DIR="${1:?usage: scan.sh <service_dir>}"
SERVICE_NAME="$(basename "${SERVICE_DIR}")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mkdir -p "${SERVICE_DIR}/security"

install_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  local version="8.24.2"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -sSL \
    "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_linux_x64.tar.gz" \
    -o "${tmp_dir}/gitleaks.tar.gz"
  tar -xzf "${tmp_dir}/gitleaks.tar.gz" -C "${tmp_dir}"
  mkdir -p "${HOME}/.local/bin"
  mv "${tmp_dir}/gitleaks" "${HOME}/.local/bin/gitleaks"
  chmod +x "${HOME}/.local/bin/gitleaks"
  export PATH="${HOME}/.local/bin:${PATH}"
}

install_gitleaks

gitleaks detect \
  --source "${SERVICE_DIR}" \
  --no-git \
  --report-format json \
  --report-path "${SERVICE_DIR}/security/gitleaks.json"

cd "${SERVICE_DIR}"

case "${SERVICE_NAME}" in
  user-service)
    npm install
    npm audit --audit-level=high --json > security/npm-audit.json
    ;;
  transaction-service)
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt -r requirements-dev.txt
    bandit -r app -f json -o security/bandit.json
    ;;
  notification-service)
    go vet ./... 2>&1 | tee security/go-vet.txt
    ;;
  *)
    echo "Unsupported service: ${SERVICE_NAME}" >&2
    exit 1
    ;;
esac

cd "${ROOT_DIR}" >/dev/null 2>&1 || true

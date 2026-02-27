#!/usr/bin/env bash
set -euo pipefail

: "${APP_HOST:?APP_HOST is required}"
: "${APP_SSH_USER:?APP_SSH_USER is required}"
: "${IMAGE_REF:?IMAGE_REF is required}"

REMOTE_SCRIPT=$(cat <<'EOF'
set -euo pipefail

IMAGE_REF="$1"
APP_NAME="devops-fastapi"
CANDIDATE_NAME="devops-fastapi-candidate"

sudo docker pull "${IMAGE_REF}"

sudo docker rm -f "${CANDIDATE_NAME}" >/dev/null 2>&1 || true
sudo docker run -d --name "${CANDIDATE_NAME}" -p 127.0.0.1:18000:8000 "${IMAGE_REF}" >/dev/null

for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:18000/ >/dev/null; then
    break
  fi
  sleep 2
  if [ "$i" = "20" ]; then
    echo "Candidate health check failed"
    sudo docker logs "${CANDIDATE_NAME}" || true
    sudo docker rm -f "${CANDIDATE_NAME}" || true
    exit 1
  fi
done

sudo docker rm -f "${APP_NAME}" >/dev/null 2>&1 || true
sudo docker run -d --name "${APP_NAME}" --restart unless-stopped -p 80:8000 "${IMAGE_REF}" >/dev/null
sudo docker rm -f "${CANDIDATE_NAME}" >/dev/null 2>&1 || true
EOF
)

ssh -o StrictHostKeyChecking=no "${APP_SSH_USER}@${APP_HOST}" "bash -s -- '${IMAGE_REF}'" <<<"${REMOTE_SCRIPT}"

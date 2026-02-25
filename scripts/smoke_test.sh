#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8000}"

echo "[smoke] Base URL: ${BASE_URL}"

health_code=$(curl -s -o /tmp/health.json -w "%{http_code}" "${BASE_URL}/healthcheck")
if [[ "$health_code" != "200" ]]; then
  echo "[smoke] /healthcheck failed with status: $health_code"
  exit 1
fi

characters_code=""
for i in {1..5}; do
  characters_code=$(curl -s -o /tmp/characters.json -w "%{http_code}" "${BASE_URL}/characters" || true)
  if [[ "$characters_code" == "200" ]]; then
    break
  fi
  echo "[smoke] /characters attempt ${i}/5 failed with status: ${characters_code}"
  cat /tmp/characters.json || true
  sleep 2
done
if [[ "$characters_code" != "200" ]]; then
  echo "[smoke] /characters failed after retries with status: $characters_code"
  exit 1
fi

python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path('/tmp/characters.json').read_text(encoding='utf-8'))
if not isinstance(payload, list):
    raise SystemExit('[smoke] /characters response is not a JSON array')
print(f'[smoke] /characters returned list with {len(payload)} items')
PY

export_code=""
for i in {1..5}; do
  export_code=$(curl -s -o /tmp/export.json -w "%{http_code}" "${BASE_URL}/characters/export-csv" || true)
  if [[ "$export_code" == "200" ]]; then
    break
  fi
  echo "[smoke] /characters/export-csv attempt ${i}/5 failed with status: ${export_code}"
  cat /tmp/export.json || true
  sleep 2
done
if [[ "$export_code" != "200" ]]; then
  echo "[smoke] /characters/export-csv failed after retries with status: $export_code"
  exit 1
fi

python3 - <<'PY'
import json
from pathlib import Path

payload = json.loads(Path('/tmp/export.json').read_text(encoding='utf-8'))
if payload.get('status') != 'success':
    raise SystemExit('[smoke] export response missing status=success')
if 'path' not in payload:
    raise SystemExit('[smoke] export response missing path')
print(f"[smoke] export response OK (path={payload['path']})")
PY

echo "[smoke] all checks passed"

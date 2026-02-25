#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8000}"

echo "[smoke] Base URL: ${BASE_URL}"

health_code=$(curl -s -o /tmp/health.json -w "%{http_code}" "${BASE_URL}/healthcheck")
if [[ "$health_code" != "200" ]]; then
  echo "[smoke] /healthcheck failed with status: $health_code"
  exit 1
fi

characters_code=$(curl -s -o /tmp/characters.json -w "%{http_code}" "${BASE_URL}/characters")
if [[ "$characters_code" != "200" ]]; then
  echo "[smoke] /characters failed with status: $characters_code"
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

export_code=$(curl -s -o /tmp/export.json -w "%{http_code}" "${BASE_URL}/characters/export-csv")
if [[ "$export_code" != "200" ]]; then
  echo "[smoke] /characters/export-csv failed with status: $export_code"
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

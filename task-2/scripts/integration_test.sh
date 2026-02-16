#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

cleanup() {
  docker compose down -v || true
}
trap cleanup EXIT

docker compose up -d --build

wait_health() {
  local name="$1"
  local i=0
  while [[ $i -lt 120 ]]; do
    status="$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || true)"
    if [[ "$status" == "healthy" ]]; then
      echo "$name is healthy"
      return 0
    fi
    sleep 2
    i=$((i + 1))
  done
  echo "Timed out waiting for $name health"
  return 1
}

wait_health task2-localstack
wait_health task2-postgres

terraform -chdir=infra/terraform init -input=false
terraform -chdir=infra/terraform apply -auto-approve -input=false

docker compose stop worker
mkdir -p data
cat > data/sample.geojson <<'EOF'
{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[-122.4194,37.7749]},"properties":{"name":"san-francisco","source":"ci"}}]}
EOF

aws --endpoint-url=http://localhost:4566 --region us-east-1 s3 cp data/sample.geojson s3://task2-ingest/sample.geojson
QUEUE_URL="$(aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs get-queue-url --queue-name task2-ingest-queue --query QueueUrl --output text)"
MSG="$(aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs receive-message --queue-url "$QUEUE_URL" --max-number-of-messages 1 --wait-time-seconds 5)"

echo "$MSG" | grep -q "sample.geojson"

RECEIPT="$(echo "$MSG" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["Messages"][0]["ReceiptHandle"])')"
aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs change-message-visibility --queue-url "$QUEUE_URL" --receipt-handle "$RECEIPT" --visibility-timeout 0 >/dev/null

docker compose start worker

for _ in $(seq 1 30); do
  COUNT="$(docker exec task2-postgres psql -U geo -d geodb -t -A -c "SELECT COUNT(*) FROM geo_features WHERE source_key='sample.geojson';")"
  if [[ "${COUNT:-0}" -ge 1 ]]; then
    echo "Integration success: rows inserted = $COUNT"
    exit 0
  fi
  sleep 2
done

echo "Integration failure: no rows inserted"
exit 1
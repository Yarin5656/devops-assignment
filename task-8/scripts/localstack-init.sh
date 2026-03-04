#!/usr/bin/env bash
# =============================================================================
# localstack-init.sh – Seed LocalStack with example secrets and resources
#
# LocalStack emulates AWS APIs locally. All commands use:
#   --endpoint-url=http://localhost:4566
#
# Zero cost: no real AWS, no charges.
# =============================================================================
set -euo pipefail

ENDPOINT="http://localhost:4566"
AWS="aws --endpoint-url=${ENDPOINT} --region us-east-1"

echo "==> Waiting for LocalStack to be ready..."
for i in $(seq 1 30); do
    if curl -sf "${ENDPOINT}/_localstack/health" | grep -q '"s3": "available"'; then
        echo "    LocalStack ready."
        break
    fi
    echo "    Waiting... ($i/30)"
    sleep 2
done

# ---------------------------------------------------------------------------
echo ""
echo "==> Creating example Secrets Manager entries..."

$AWS secretsmanager create-secret \
    --name "url-shortener/app-secret-key" \
    --secret-string "REPLACE_WITH_REAL_SECRET_IN_PRODUCTION" \
    2>/dev/null || \
$AWS secretsmanager put-secret-value \
    --secret-id "url-shortener/app-secret-key" \
    --secret-string "REPLACE_WITH_REAL_SECRET_IN_PRODUCTION"

echo "    Created: url-shortener/app-secret-key"

$AWS secretsmanager create-secret \
    --name "url-shortener/db-password" \
    --secret-string "CHANGEME_db_password_placeholder" \
    2>/dev/null || \
$AWS secretsmanager put-secret-value \
    --secret-id "url-shortener/db-password" \
    --secret-string "CHANGEME_db_password_placeholder"

echo "    Created: url-shortener/db-password"

# ---------------------------------------------------------------------------
echo ""
echo "==> Creating SSM Parameter Store entries..."

$AWS ssm put-parameter \
    --name "/url-shortener/staging/base-url" \
    --value "http://url-shortener-staging.local" \
    --type String \
    --overwrite

$AWS ssm put-parameter \
    --name "/url-shortener/production/base-url" \
    --value "https://short.example.com" \
    --type String \
    --overwrite

echo "    Created SSM parameters."

# ---------------------------------------------------------------------------
echo ""
echo "==> Creating S3 bucket for artefacts..."
$AWS s3 mb s3://url-shortener-artefacts 2>/dev/null || true
echo "    s3://url-shortener-artefacts created."

# ---------------------------------------------------------------------------
echo ""
echo "✅ LocalStack seeded."
echo ""
echo "   List secrets:"
echo "     aws --endpoint-url=${ENDPOINT} secretsmanager list-secrets"
echo ""
echo "   Read a secret:"
echo "     aws --endpoint-url=${ENDPOINT} secretsmanager get-secret-value \\"
echo "         --secret-id url-shortener/db-password"
echo ""
echo "   List S3:"
echo "     aws --endpoint-url=${ENDPOINT} s3 ls"

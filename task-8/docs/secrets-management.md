# Secrets Management

## Principles

1. **No secrets in git** – not in code, Dockerfiles, values files, or CI config.
2. **No secrets in Docker images** – build args are not used for secrets.
3. **Least-privilege** – each workload gets only the secrets it needs.
4. **Rotation support** – rotation must be possible without redeploying the app.

---

## Chosen Approach: Kubernetes Secrets + External Secrets Operator (ESO)

For local development: **Kubernetes Secrets** (base64, not encrypted at rest by default).
For production: **External Secrets Operator** pulling from LocalStack (dev) / AWS Secrets Manager (prod).

### Why ESO?
- Secrets live in the secret store, not in git.
- Automatic sync + rotation without redeployment.
- Works with LocalStack for zero-cost local testing.

---

## Required Secrets (Placeholders Only)

| Secret name | Where used | Value |
|-------------|-----------|-------|
| `url-shortener/app-secret-key` | App (future JWT signing) | `REPLACE_WITH_REAL_SECRET` |
| `url-shortener/db-password` | Future Redis/PG auth | `REPLACE_WITH_REAL_SECRET` |
| `KUBECONFIG_STAGING` | CI/CD pipeline | base64 kubeconfig |
| `KUBECONFIG_PRODUCTION` | CI/CD pipeline | base64 kubeconfig |
| `GHCR_TOKEN` | CI image push | GitHub PAT with `packages:write` |

---

## Local Development (LocalStack)

LocalStack emulates AWS Secrets Manager at `http://localhost:4566`.
All AWS CLI calls MUST use `--endpoint-url=http://localhost:4566`.

```bash
# Seed LocalStack with example secrets
./scripts/localstack-init.sh

# Read a secret
aws --endpoint-url=http://localhost:4566 secretsmanager get-secret-value \
    --secret-id url-shortener/db-password

# Create/update a secret
aws --endpoint-url=http://localhost:4566 secretsmanager put-secret-value \
    --secret-id url-shortener/db-password \
    --secret-string "NEW_PASSWORD"
```

---

## Kubernetes Secrets (local kind cluster)

For quick local testing, create a Kubernetes Secret directly:

```bash
# Create secret (values are base64-encoded automatically by kubectl)
kubectl create secret generic url-shortener-secret \
    --from-literal=APP_SECRET_KEY="local-dev-secret-not-for-prod" \
    -n url-shortener-staging \
    --context kind-url-shortener-local

# Verify (values will be base64-encoded)
kubectl get secret url-shortener-secret \
    -n url-shortener-staging \
    -o yaml
```

**Never commit the above secret YAML to git.**

---

## External Secrets Operator Setup (Production Pattern)

Install ESO in the cluster:
```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

Create a `SecretStore` pointing to LocalStack (or real AWS in prod):
```yaml
# infra/eso/secret-store.yaml  (not committed with real credentials)
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: localstack-secrets
  namespace: url-shortener-staging
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      endpoint: http://localstack.default.svc.cluster.local:4566  # in-cluster LocalStack
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: aws-creds
            key: access-key
          secretAccessKeySecretRef:
            name: aws-creds
            key: secret-key
```

Create an `ExternalSecret`:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: url-shortener-secret
  namespace: url-shortener-staging
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: localstack-secrets
    kind: SecretStore
  target:
    name: url-shortener-secret
    creationPolicy: Owner
  data:
    - secretKey: APP_SECRET_KEY
      remoteRef:
        key: url-shortener/app-secret-key
    - secretKey: DB_PASSWORD
      remoteRef:
        key: url-shortener/db-password
```

ESO will create the Kubernetes Secret and refresh it every hour.

---

## Secret Rotation Procedure

### Rotate a secret (e.g., db-password)

```bash
# Step 1: Update the secret value in the store
aws --endpoint-url=http://localhost:4566 secretsmanager put-secret-value \
    --secret-id url-shortener/db-password \
    --secret-string "NEW_ROTATED_PASSWORD"

# Step 2: If using ESO, it auto-syncs within refreshInterval (default 1h).
# Force immediate refresh:
kubectl annotate externalsecret url-shortener-secret \
    force-sync=$(date +%s) -n url-shortener-staging --overwrite

# Step 3: Verify the Kubernetes Secret was updated:
kubectl get secret url-shortener-secret \
    -n url-shortener-staging \
    -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Step 4: Rolling restart to pick up new secret (if mounted as env var):
kubectl rollout restart deployment/url-shortener -n url-shortener-staging

# Step 5: Verify app is healthy:
kubectl rollout status deployment/url-shortener -n url-shortener-staging
```

### KUBECONFIG rotation
1. Regenerate kubeconfig from the cluster admin.
2. Base64-encode: `base64 -w0 new-kubeconfig.yaml`
3. Update GitHub Secret: **Settings → Secrets → KUBECONFIG_STAGING → Update**.
4. No pod restart needed (CI/CD reads at workflow run time).

---

## Sealed Secrets (Alternative)

If you prefer to commit encrypted secrets to git:

```bash
# Install kubeseal CLI
brew install kubeseal  # or: https://github.com/bitnami-labs/sealed-secrets/releases

# Install controller in cluster
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# Create a SealedSecret from a plain Secret
kubectl create secret generic url-shortener-secret \
    --from-literal=APP_SECRET_KEY="value" \
    --dry-run=client -o yaml | \
  kubeseal --format yaml > k8s/base/sealed-secret.yaml  # safe to commit

# Unseal happens automatically in-cluster
```

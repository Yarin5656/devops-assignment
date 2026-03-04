# Operations Runbook – URL Shortener

**Audience:** On-call DevOps engineer
**Last updated:** See git blame
**Escalation:** platform-team@example.com

---

## Quick Reference

| Task | Command |
|------|---------|
| Check staging pods | `kubectl get pods -n url-shortener-staging` |
| Check prod pods | `kubectl get pods -n url-shortener-production` |
| View staging logs | `kubectl logs -l app=url-shortener -n url-shortener-staging --tail=100` |
| Rollback staging | `kubectl rollout undo deployment/url-shortener -n url-shortener-staging` |
| Rollback production | `./scripts/rollback.sh production` |
| Restart deployment | `kubectl rollout restart deployment/url-shortener -n <ns>` |
| Check rollout history | `kubectl rollout history deployment/url-shortener -n <ns>` |

---

## 1. CI Pipeline Failure

### 1a. Lint failure

**Symptom:** GitHub Actions `lint` job fails.
**Cause:** Code style violation.

```bash
# Reproduce locally
cd task-8
make lint

# Auto-fix
make lint-fix
git add -p && git commit -m "fix: lint issues"
```

Check the job output for which file/line failed (ruff reports exact location).

---

### 1b. Test failure

**Symptom:** `test` job fails, coverage below 80%, or test assertion error.

```bash
# Reproduce locally
make test

# Run a single test for debugging
cd app && pytest tests/test_main.py::test_resolve_not_found -v -s
```

**Coverage below threshold:**
```bash
cd app && pytest tests/ --cov=. --cov-report=html
# Open htmlcov/index.html in browser to find uncovered lines
```

---

### 1c. Security scan failure (Trivy)

**Symptom:** `security-scan` job fails with CRITICAL or HIGH CVE findings.

**Steps:**
1. Read the Trivy table output in the job log.
2. Identify the affected package (OS package or Python dep).

**Fix options:**

```bash
# Option A: Update Python deps
cd task-8/app
pip list --outdated
# Update requirements.txt with patched version

# Option B: Use newer base image
# Edit Dockerfile: FROM python:3.12-slim → python:3.12.X-slim (latest patch)

# Option C: Add Trivy ignore for unfixable CVE
# Create .trivyignore at task-8/.trivyignore:
echo "CVE-XXXX-YYYYY" >> .trivyignore
# (only do this after security team review and documenting the exception)
```

---

### 1d. Image push failure (GHCR / local registry)

**Symptom:** `build-push` job fails with authentication error.

```
Error: unauthorized: unauthenticated
```

**GHCR fix:**
1. Check GitHub Secret `GHCR_TOKEN` is set: **Settings → Secrets → Actions**.
2. Verify token has `packages:write` scope.
3. Verify token belongs to an account with access to the repo.

**Local registry fix:**
```bash
# Restart local registry
docker restart kind-registry

# Verify it's accessible
curl http://localhost:5001/v2/
```

---

## 2. Deployment Failure

### 2a. Rollout stalls (pods not becoming ready)

**Symptom:** `kubectl rollout status` hangs or times out.

```bash
# 1. Check pod status
kubectl get pods -n url-shortener-staging -w

# 2. Describe failing pods
kubectl describe pod -l app=url-shortener -n url-shortener-staging

# 3. Look for: CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending
```

**ImagePullBackOff:**
```bash
# Check image exists in registry
docker pull localhost:5001/url-shortener:THE_TAG

# Or check GHCR
docker pull ghcr.io/<org>/url-shortener:THE_TAG
```

**CrashLoopBackOff:**
```bash
# Read logs from previous crashed container
kubectl logs -l app=url-shortener -n url-shortener-staging --previous
```

**OOMKilled:**
```bash
# Check memory limits in configmap/deployment
kubectl describe deployment url-shortener -n url-shortener-staging | grep -A3 Limits
# Increase limits in k8s/overlays/staging/patch-deployment.yaml
```

**Rollback:**
```bash
kubectl rollout undo deployment/url-shortener -n url-shortener-staging
kubectl rollout status deployment/url-shortener -n url-shortener-staging
```

---

### 2b. Production rollout failure

**Symptom:** CD pipeline fails after production deploy started.

**Immediate action:**
```bash
# The CD script auto-rolls back; verify it happened:
kubectl rollout history deployment/url-shortener -n url-shortener-production

# Manual rollback if needed:
./scripts/rollback.sh production
# or:
kubectl rollout undo deployment/url-shortener -n url-shortener-production
kubectl rollout status deployment/url-shortener -n url-shortener-production --timeout=120s
```

**Post-mortem checklist:**
- [ ] Was staging successfully tested before production?
- [ ] Was the image tag correct?
- [ ] Were there resource limit changes that caused OOM?
- [ ] Did a config change (ConfigMap) cause the crash?

---

### 2c. Namespace or cluster unreachable

**Symptom:** `kubectl` commands fail with connection refused or timeout.

```bash
# Check cluster is running (kind)
kind get clusters

# If cluster stopped, restart:
docker start $(docker ps -a --filter name=url-shortener-local -q)

# Recreate if needed (data in InMemoryStorage will be lost):
make kind-down && make kind-up
```

---

## 3. Service Unhealthy After Release

### 3a. /healthz returns non-200

```bash
# Port-forward to pod directly (bypasses Service)
kubectl port-forward \
    $(kubectl get pod -l app=url-shortener -n url-shortener-staging -o name | head -1) \
    8080:8000 -n url-shortener-staging

curl -v http://localhost:8080/healthz
```

If `/healthz` returns 500, the app is broken at startup level. Check logs:
```bash
kubectl logs -l app=url-shortener -n url-shortener-staging --tail=200
```

---

### 3b. High error rate after release

**Detection:** Prometheus alert fires: `HighErrorRate` (5xx > 5% for 2min).

```bash
# 1. Check error rate in metrics
kubectl port-forward svc/url-shortener 8080:80 -n url-shortener-staging
curl http://localhost:8080/metrics | grep http_requests_total

# 2. Check logs for exception tracebacks
kubectl logs -l app=url-shortener -n url-shortener-staging --tail=500 | grep ERROR

# 3. If error rate high: rollback
./scripts/rollback.sh staging
```

---

### 3c. High latency after release

**Detection:** Prometheus alert: `HighLatency` (p99 > 1s).

```bash
# Check latency from metrics
curl http://localhost:8080/metrics | grep http_request_duration

# Check if it's CPU throttling
kubectl top pods -n url-shortener-staging

# If CPU at limit: increase limits in patch-deployment.yaml and redeploy
# Or scale horizontally:
kubectl scale deployment url-shortener --replicas=3 -n url-shortener-staging
```

---

### 3d. Pod eviction / OOMKilled after release

**Detection:** Pod restarts increasing; `kubectl describe pod` shows OOMKilled.

```bash
kubectl get events -n url-shortener-staging --sort-by='.lastTimestamp' | tail -20
```

**Immediate fix:**
```bash
# Increase memory limit (temporary)
kubectl set resources deployment/url-shortener \
    -n url-shortener-staging \
    --limits=memory=256Mi --requests=memory=128Mi

# Long-term: update k8s/overlays/staging/patch-deployment.yaml
```

---

## 4. Secret Rotation Emergency

If a secret is compromised:

```bash
# 1. Revoke the secret at the source (GitHub, LocalStack, etc.)

# 2. Create new secret value
aws --endpoint-url=http://localhost:4566 secretsmanager put-secret-value \
    --secret-id url-shortener/app-secret-key \
    --secret-string "NEW_SECRET_VALUE"

# 3. Update Kubernetes Secret directly (if not using ESO)
kubectl create secret generic url-shortener-secret \
    --from-literal=APP_SECRET_KEY="NEW_SECRET_VALUE" \
    -n url-shortener-production \
    --dry-run=client -o yaml | kubectl apply -f -

# 4. Rolling restart to pick up new secret
kubectl rollout restart deployment/url-shortener -n url-shortener-production
kubectl rollout status deployment/url-shortener -n url-shortener-production

# 5. Verify app is healthy
kubectl get pods -n url-shortener-production
```

---

## 5. LocalStack Not Responding

```bash
# Check container
docker ps | grep localstack

# View logs
docker logs url-shortener-localstack --tail=50

# Restart
docker compose restart localstack

# Wait for healthy (up to 30s)
curl http://localhost:4566/_localstack/health
```

---

## 6. Escalation Criteria

Escalate to senior engineer if:
- Production rollback fails (pods not stabilizing after undo)
- Data corruption suspected (URL mappings returning wrong values)
- Cluster unreachable and cannot be recreated quickly
- Secret compromise confirmed in production

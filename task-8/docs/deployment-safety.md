# Deployment Safety & Reliability

## Rolling Updates (Default)

All deployments use Kubernetes rolling update strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0   # Never take pods below desired count → zero downtime
    maxSurge: 1         # Allow one extra pod during transition
```

**What happens during a deploy:**
1. New pod starts and passes `startupProbe` (up to 30s)
2. New pod passes `readinessProbe` → added to Service endpoint list
3. One old pod is terminated (graceful shutdown, 30s window)
4. Repeat for each replica

---

## Canary Deployment (Manual)

For production risk reduction, deploy to a small pod subset first.

### With Kustomize (manual canary)

```bash
# Step 1: Deploy canary at 1 replica (alongside 3 stable replicas)
kubectl patch deployment url-shortener \
    -n url-shortener-production \
    --type=json \
    -p='[{"op":"replace","path":"/spec/replicas","value":4}]'

# Step 2: Deploy new image to 1 canary pod using a separate deployment
kubectl create deployment url-shortener-canary \
    --image=localhost:5001/url-shortener:NEW_TAG \
    -n url-shortener-production
kubectl scale deployment url-shortener-canary --replicas=1 -n url-shortener-production

# Step 3: Monitor error rate for 10 minutes
watch -n5 "kubectl top pods -n url-shortener-production"

# Step 4a: Success → promote
kubectl set image deployment/url-shortener \
    url-shortener=localhost:5001/url-shortener:NEW_TAG \
    -n url-shortener-production
kubectl delete deployment url-shortener-canary -n url-shortener-production

# Step 4b: Failure → abort canary
kubectl delete deployment url-shortener-canary -n url-shortener-production
# Stable deployment untouched
```

### With Argo Rollouts (recommended for automation)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: url-shortener
spec:
  strategy:
    canary:
      steps:
        - setWeight: 20      # 20% traffic to new version
        - pause: {duration: 5m}
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100
      analysis:
        templates:
          - templateName: error-rate
        args:
          - name: service-name
            value: url-shortener
```

---

## Auto-Rollback Conditions

### Condition 1: Readiness probe failure

If the new pod fails `readinessProbe` 3 consecutive times within `failureThreshold × periodSeconds = 30s`, Kubernetes:
1. Never adds the pod to the endpoint list
2. Rolling update stalls (maxUnavailable=0 means no old pod is removed)
3. After `progressDeadlineSeconds` (default 600s), deployment is marked **Failed**

**Auto-rollback in CI/CD pipeline:**
```bash
if ! kubectl rollout status deployment/url-shortener --timeout=180s; then
    kubectl rollout undo deployment/url-shortener
fi
```

### Condition 2: High error rate (Prometheus alert → webhook)

Use Prometheus Alertmanager with a webhook to trigger rollback:

```yaml
# alertmanager.yml
receivers:
  - name: auto-rollback
    webhook_configs:
      - url: http://rollback-controller/trigger
        send_resolved: false
```

The rollback controller runs:
```bash
kubectl rollout undo deployment/url-shortener -n url-shortener-production
```

---

## Simulated Failure Scenario

### Scenario: Bad image deployed (app crashes on startup)

```
Timeline:
T+0:00  Developer pushes broken code → PR merged
T+0:05  CI builds image with crashing startup bug
T+0:10  CD deploys to staging: url-shortener:broken
T+0:12  New pod starts, startupProbe fails (app crashes)
T+0:42  Pod fails 10 startupProbe checks → CrashLoopBackOff
T+0:45  Rollout timeout (stalled: maxUnavailable=0, no old pods removed)
T+0:45  CI script detects: `kubectl rollout status` exits non-zero
T+0:46  CI runs: `kubectl rollout undo deployment/url-shortener -n staging`
T+0:48  Old (good) pods restored
T+0:50  Alert fired: PodNotReady (Prometheus → Alertmanager → Slack)
```

**Manual detection steps:**
```bash
# 1. Check rollout status
kubectl rollout status deployment/url-shortener -n url-shortener-staging

# 2. Check pod events
kubectl describe pod -l app=url-shortener -n url-shortener-staging | grep -A5 Events

# 3. Check logs
kubectl logs -l app=url-shortener -n url-shortener-staging --previous

# 4. Rollback
kubectl rollout undo deployment/url-shortener -n url-shortener-staging

# 5. Verify
kubectl rollout status deployment/url-shortener -n url-shortener-staging
kubectl get pods -n url-shortener-staging
```

---

## Blue/Green Deployment (Manual)

```bash
# Blue is current production; deploy Green side-by-side

# Deploy Green
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: url-shortener-green
  namespace: url-shortener-production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: url-shortener
      slot: green
  template:
    metadata:
      labels:
        app: url-shortener
        slot: green
    spec:
      containers:
        - name: url-shortener
          image: localhost:5001/url-shortener:NEW_TAG
EOF

# Wait for Green to be ready
kubectl rollout status deployment/url-shortener-green -n url-shortener-production

# Smoke test Green directly
kubectl port-forward deployment/url-shortener-green 8001:8000 -n url-shortener-production &
curl http://localhost:8001/healthz

# Switch Service to Green
kubectl patch service url-shortener -n url-shortener-production \
    -p '{"spec":{"selector":{"slot":"green"}}}'

# Verify traffic flows to Green; then remove Blue
kubectl delete deployment url-shortener-blue -n url-shortener-production
kubectl rename deployment url-shortener-green url-shortener -n url-shortener-production
```

---

## Pod Disruption Budget

Production PDB ensures at least 2 replicas are available during voluntary disruptions (node drains, upgrades):

```yaml
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: url-shortener
      environment: production
```

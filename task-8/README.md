# URL Shortener – End-to-End DevOps Setup

> **Zero-cost mode:** Everything runs locally.
> No real AWS, no paid cloud. LocalStack emulates AWS APIs. kind provides local Kubernetes.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Local Development (Docker Compose)](#local-development)
3. [Running Tests](#running-tests)
4. [Linting](#linting)
5. [Docker Image](#docker-image)
6. [Local Kubernetes (kind)](#local-kubernetes-kind)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [Staging Deploy](#staging-deploy)
9. [Production Deploy](#production-deploy)
10. [Secrets Management](#secrets-management)
11. [Observability](#observability)
12. [Branching Strategy](#branching-strategy)
13. [Required Secrets (Placeholders)](#required-secrets)
14. [Folder Structure](#folder-structure)

---

## Architecture

```
POST /shorten  {"url": "https://example.com"}  →  {"code": "aB3xYz", "short_url": "http://localhost:8000/aB3xYz"}
POST /resolve  {"code": "aB3xYz"}             →  {"url": "https://example.com"}
GET  /healthz                                  →  {"status": "ok", "version": "dev"}
GET  /metrics                                  →  Prometheus text format
```

See [docs/architecture.md](docs/architecture.md) for full diagram.

**Tech stack:**
- App: Python 3.12, FastAPI, uvicorn, prometheus-client
- Local stack: Docker Compose + LocalStack (AWS emulation) + Redis
- CI: GitHub Actions + Jenkinsfile
- CD: kustomize overlays (staging/production) on kind cluster
- Image registry: GHCR (CI) / localhost:5001 (kind local)

---

## Prerequisites

| Tool | Min version | Install |
|------|------------|---------|
| Docker Desktop | 4.x | https://docs.docker.com/desktop/ |
| Python | 3.12 | https://python.org |
| make | 3.81 | Git Bash on Windows: bundled with git |
| kind | 0.22 | `winget install Kubernetes.kind` |
| kubectl | 1.29 | `winget install Kubernetes.kubectl` |
| kustomize | 5.x | `winget install kubernetes-sigs.kustomize` |
| AWS CLI | 2.x | For LocalStack: `winget install Amazon.AWSCLI` |

> **Windows users:** All commands below run in **Git Bash** (not PowerShell or cmd).

---

## Local Development

The fastest way to start the full stack (app + Redis + LocalStack):

```bash
cd task-8

# Build and start all services
make up

# Or: start only the app (no Redis/LocalStack)
docker compose up app
```

Services:
| Service | URL | Purpose |
|---------|-----|---------|
| App | http://localhost:8000 | API |
| Swagger UI | http://localhost:8000/docs | Interactive docs |
| Metrics | http://localhost:8000/metrics | Prometheus scrape |
| LocalStack | http://localhost:4566 | AWS API emulation |
| Redis | localhost:6379 | (future persistence) |

### Test the API

```bash
# Shorten a URL
curl -s -X POST http://localhost:8000/shorten \
     -H "Content-Type: application/json" \
     -d '{"url": "https://example.com"}' | python -m json.tool

# Resolve it (replace <code> with the value returned above)
curl -s -X POST http://localhost:8000/resolve \
     -H "Content-Type: application/json" \
     -d '{"code": "<code>"}' | python -m json.tool

# Health check
curl http://localhost:8000/healthz
```

### LocalStack (zero-cost AWS emulation)

All AWS CLI commands **must** use `--endpoint-url=http://localhost:4566`.

```bash
# Seed LocalStack with example secrets
make localstack-init

# List secrets
aws --endpoint-url=http://localhost:4566 secretsmanager list-secrets

# Get a secret
aws --endpoint-url=http://localhost:4566 secretsmanager get-secret-value \
    --secret-id url-shortener/db-password
```

---

## Running Tests

```bash
# Install dependencies (one-time)
make install

# Run tests with coverage
make test

# CI mode (JUnit XML + coverage XML output)
make test-ci
```

**Coverage gate:** CI fails if coverage drops below **80%**.

```bash
# Debug a single test
cd app && pytest tests/test_main.py::test_full_roundtrip -v -s
```

---

## Linting

```bash
# Check (no auto-fix)
make lint

# Auto-fix lint issues
make lint-fix
```

Uses [ruff](https://docs.astral.sh/ruff/) – fast Python linter + formatter.

---

## Docker Image

### Build locally

```bash
make build
# Produces: url-shortener:local

# Or with explicit version + SHA
make build-prod VERSION=1.2.3 SHA=$(git rev-parse --short HEAD)
```

### Image tagging strategy

| Tag | When | Example |
|-----|------|---------|
| `<semver>` | Release tag pushed | `1.2.3` |
| `<semver>-<sha7>` | Release tag pushed | `1.2.3-a1b2c3d` |
| `develop-<sha7>` | develop branch push | `develop-a1b2c3d` |
| `latest` | main branch push | `latest` |
| `local` | Local `make build` | `local` |

### Vulnerability scan (Trivy)

```bash
make scan           # fails on CRITICAL/HIGH
make scan-table     # prints table, no exit code gate
```

---

## Local Kubernetes (kind)

### Create cluster + local registry

```bash
make kind-up
# Creates: kind cluster 'url-shortener-local' + local registry at localhost:5001
# Creates namespaces: url-shortener-staging, url-shortener-production
```

### Build and load image into cluster

```bash
make build          # build url-shortener:local
make kind-load      # push to localhost:5001 + load into kind nodes
```

### Port-forward to access services

```bash
kubectl port-forward svc/url-shortener 8080:80 \
    -n url-shortener-staging \
    --context kind-url-shortener-local
curl http://localhost:8080/healthz
```

### Tear down

```bash
make kind-down
```

---

## CI/CD Pipeline

### GitHub Actions (primary)

> **Note:** Workflows live at `task-8/.github/workflows/`.
> In a real repo, copy them to the repo root `.github/workflows/` so GitHub picks them up.
> Or symlink: `ln -s task-8/.github .github` from the repo root.

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `pr.yml` | PR → main, develop | lint → test → trivy scan |
| `ci.yml` | Push to main/develop | lint → test → scan → build → push → trigger staging |
| `cd.yml` | `workflow_dispatch` or `v*.*.*` tag | deploy staging (auto) / production (manual approval) |

### Flow

```
feature/* ──PR──► develop ──push──► CI: lint+test+scan+build+push
                                         │
                                         └──► CD: auto-deploy → staging
                                                      │
                               QA validates staging   │
                                                      │
develop ──PR──► main ──tag v1.2.3──► CD: [manual approve] ──► production
```

### Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `GHCR_TOKEN` | GitHub PAT with `packages:write` (or use `GITHUB_TOKEN`) |
| `KUBECONFIG_STAGING` | `base64 -w0 ~/.kube/url-shortener-local.yaml` |
| `KUBECONFIG_PRODUCTION` | Same cluster or separate prod cluster kubeconfig |

```bash
# Get kubeconfig for GitHub Secret
kind get kubeconfig --name url-shortener-local | base64 -w0
# Copy output → GitHub → Settings → Secrets → KUBECONFIG_STAGING
```

### Jenkins (alternative)

```bash
# Run pipeline locally (no Jenkins required)
./scripts/run-pipeline-local.sh

# Skip vulnerability scan (faster iteration)
./scripts/run-pipeline-local.sh --skip-scan

# With staging deploy
./scripts/run-pipeline-local.sh --deploy
```

See `Jenkinsfile` for the full declarative pipeline with all stages.

---

## Staging Deploy

Staging auto-deploys on every push to `develop` or `main` via CI.

**Manual staging deploy:**
```bash
make deploy-staging IMAGE_TAG=local
# or
./scripts/deploy-staging.sh local
```

**What happens:**
1. Image tagged + pushed to `localhost:5001/url-shortener:<tag>`
2. `kustomize edit set image` updates the overlay
3. `kubectl apply` applies manifests to `url-shortener-staging` namespace
4. `kubectl rollout status` waits up to 120s
5. On failure: automatic rollback

---

## Production Deploy

Production requires a **git tag** (auto-trigger) or **manual approval** (workflow_dispatch).

### Via git tag (CI/CD)
```bash
git tag -s v1.2.3 -m "Release 1.2.3"
git push origin v1.2.3
# → GitHub environment protection page shows "Review deployments"
# → Reviewer clicks "Approve and deploy"
```

### Manual (local)
```bash
./scripts/deploy-production.sh 1.2.3-abc1234
# Prompts for confirmation before applying
```

### Rollback

```bash
# Staging
./scripts/rollback.sh staging

# Production (with confirmation prompt)
./scripts/rollback.sh production

# Rollback to specific revision
./scripts/rollback.sh production 3
```

---

## Secrets Management

**Approach:** Kubernetes Secrets + External Secrets Operator (ESO) pulling from LocalStack.

- No secrets in git, CI config, or Docker images.
- LocalStack emulates AWS Secrets Manager at `http://localhost:4566`.
- Secret rotation: update in LocalStack → ESO auto-syncs → pod rolling restart.

See [docs/secrets-management.md](docs/secrets-management.md) for full details and rotation procedure.

---

## Observability

### Metrics
App exposes Prometheus metrics at `GET /metrics`:
- `http_requests_total` – count by method/endpoint/status
- `http_request_duration_seconds` – latency histogram
- `url_shorten_total`, `url_resolve_total{result}` – business metrics

### Logs
Structured JSON logs on stdout:
```bash
docker compose logs -f app
# or
kubectl logs -l app=url-shortener -n url-shortener-staging -f
```

See [docs/observability.md](docs/observability.md) for Prometheus, Grafana, Loki setup.

---

## Branching Strategy

See [docs/branching-strategy.md](docs/branching-strategy.md) for full model.

Summary:
- `feature/*` → PR → `develop` (1 approval)
- `develop` → auto-deploy staging
- `develop` → PR → `main` (2 approvals)
- tag `v*.*.*` → deploy production (manual approval)

---

## Required Secrets

> No real secrets are committed to this repository. All values below are **placeholders**.

| Secret | Where to set | Placeholder value |
|--------|-------------|-------------------|
| `GHCR_TOKEN` | GitHub Secrets | `ghp_XXXXXXXXXXXXXXXXXXXX` |
| `KUBECONFIG_STAGING` | GitHub Secrets | base64 of `kind get kubeconfig` |
| `KUBECONFIG_PRODUCTION` | GitHub Secrets | base64 of prod kubeconfig |
| `APP_SECRET_KEY` | LocalStack / K8s Secret | `REPLACE_WITH_REAL_SECRET` |
| `DB_PASSWORD` | LocalStack / K8s Secret | `REPLACE_WITH_REAL_SECRET` |
| `REGISTRY_CREDENTIALS` (Jenkins) | Jenkins Credentials | username+PAT |

---

## Folder Structure

```
task-8/
├── app/                         # Application source
│   ├── main.py                  # FastAPI app, routes, middleware
│   ├── models.py                # Pydantic request/response models
│   ├── storage.py               # URLStorage ABC + InMemoryStorage
│   ├── metrics.py               # Prometheus metric definitions
│   ├── requirements.txt         # Python dependencies
│   └── tests/
│       └── test_main.py         # pytest test suite (>80% coverage)
│
├── k8s/                         # Kustomize manifests
│   ├── base/                    # Base manifests (Deployment, Service, ConfigMap)
│   └── overlays/
│       ├── staging/             # 1 replica, DEBUG logging
│       └── production/          # 3 replicas, HPA, PDB
│
├── helm/url-shortener/          # Helm chart (alternative to kustomize)
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-staging.yaml
│   ├── values-production.yaml
│   └── templates/
│
├── .github/workflows/
│   ├── pr.yml                   # PR: lint + test + scan
│   ├── ci.yml                   # Push: + build + push image
│   └── cd.yml                   # Deploy: staging (auto) + production (manual)
│
├── infra/kind/cluster.yaml      # kind cluster configuration
│
├── scripts/
│   ├── setup-kind.sh            # Create kind cluster + local registry
│   ├── deploy-staging.sh        # Deploy to staging namespace
│   ├── deploy-production.sh     # Deploy to production (with confirmation)
│   ├── rollback.sh              # Rollback a deployment
│   ├── localstack-init.sh       # Seed LocalStack with example secrets
│   └── run-pipeline-local.sh   # Run full CI pipeline locally
│
├── docs/
│   ├── architecture.md          # System architecture diagram
│   ├── branching-strategy.md    # Git branching model
│   ├── secrets-management.md    # Secret rotation + ESO setup
│   ├── observability.md         # Metrics, logging, alerting guide
│   └── deployment-safety.md     # Rolling/canary/blue-green + auto-rollback
│
├── Dockerfile                   # Multi-stage, non-root, production-optimized
├── docker-compose.yml           # Local dev: app + redis + localstack
├── Makefile                     # Developer convenience targets
├── Jenkinsfile                  # Declarative Jenkins pipeline
├── .dockerignore
├── .gitignore
├── README.md                    # This file
└── RUNBOOK.md                   # Ops runbook
```

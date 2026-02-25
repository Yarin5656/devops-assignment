# RUNBOOK.md — Local-Only Execution Order (WSL Ubuntu)

## 0) Prerequisites
- Docker Desktop (Linux containers)
- kubectl, kind, helm, terraform, jq, openssl
- `/etc/hosts` entries (local):
  - `127.0.0.1 app.local`
  - `127.0.0.1 jenkins.local`

## 1) Bootstrap local platform
1. Create kind cluster.
2. Install NGINX Ingress Controller.
3. Create namespace `devops`.
4. Install local container registry (or connect to LocalStack ECR emulation mode).

## 2) Build and test app image
1. Build Docker image from `app/`.
2. Push image to selected private local registry.
3. Run smoke test locally with curl.

## 3) Deploy app to Kubernetes
1. Apply/upgrade manifests (or Helm) into `devops` namespace.
2. Create TLS secret.
3. Apply ingress with HTTPS + redirect.
4. Validate service over HTTPS.

## 4) Deploy Jenkins
1. Deploy Jenkins locally (target architecture phase decision).
2. Expose Jenkins with TLS ingress only.
3. Configure required credentials placeholders.

## 5) Configure pipelines A/B/C
1. Pipeline A: build/push/deploy on merge-to-main trigger model.
2. Pipeline B: parameters (`REPLICAS`, `IMAGE_TAG`) and rollout.
3. Pipeline C: parameterized file content injection into pod filesystem.

## 6) Validate and collect evidence
1. Run each pipeline successfully at least once.
2. Collect logs, screenshots, and curl outputs.
3. Fill `docs/EVIDENCE_CHECKLIST.md`.

## Notes
- Never run Terraform/AWS CLI against real cloud endpoints.
- LocalStack endpoint only when AWS APIs are required.

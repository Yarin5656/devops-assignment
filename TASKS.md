# TASKS.md — AUI DevOps Assignment 2024 (Local-Only Master Checklist)

## Constraints (must keep)
- [ ] No real cloud calls (AWS via LocalStack endpoint `http://localhost:4566` only)
- [ ] No real cloud credentials used
- [ ] Work only inside this repo
- [ ] No destructive commands without explicit approval
- [ ] No secrets committed

---

## Phase 1 — Structure and traceability
- [x] `app/` contains service source (or clear placeholder notes)
- [x] `docker/` created (`Dockerfile`, `.dockerignore`, `README.md`)
- [x] `k8s/` created (`namespace-devops.yaml`, `app/*`, `jenkins/*`)
- [x] `jenkins/` created (`Jenkinsfile.A/B/C`, `README.md`)
- [x] `iac/` created with LocalStack-oriented Terraform scaffolding
- [x] `scripts/` helper scripts scaffolded
- [x] `evidence/` folders created for screenshots/logs
- [x] `README.md` includes Requirement → File(s) mapping
- [x] `docs/RUNBOOK.md` updated with local-only step-by-step order

---

## MVP path (minimum to pass)

### A) IaC + platform
- [ ] Implement Terraform resources in `iac/terraform/*` for LocalStack-safe demo
- [ ] Implement cluster bootstrap commands in `scripts/setup-kind.sh`
- [ ] Implement ingress + namespace setup in scripts/manifests

### B) App container
- [ ] Finalize Docker image hardening in `docker/Dockerfile`
- [ ] Validate local image build/run path from runbook

### C) Jenkins pipelines A/B/C
- [ ] Implement Pipeline A logic in `jenkins/Jenkinsfile.A`
- [ ] Implement Pipeline B logic in `jenkins/Jenkinsfile.B`
- [ ] Implement Pipeline C logic in `jenkins/Jenkinsfile.C`

### D) HTTPS-only
- [ ] Finalize TLS generation/apply in `scripts/setup-tls.sh`
- [ ] Enforce ingress HTTP→HTTPS redirect for app and Jenkins

### E) Evidence
- [ ] Capture pipeline A/B/C success logs into `evidence/logs/`
- [ ] Capture required screenshots into `evidence/screenshots/`
- [ ] Add HTTPS curl proofs and resource outputs

---

## Production-like path (better quality)
- [ ] Non-root containers + read-only root FS where practical
- [ ] Liveness/readiness probes + resource limits/requests
- [ ] Least-privilege RBAC/service accounts for Jenkins deploy
- [ ] Secret templates and masked logging
- [ ] Deterministic rebuild scripts for clean machines

## Bonus items
- [ ] Local observability addon
- [ ] Policy/security scans in CI
- [ ] Optional real-cloud template docs (not executed)

# AUI DevOps Assignment 2024 — Local-Only Implementation Repo

This repository is organized for a **local-only** assignment execution flow.

## Safety policy (hard)
- No real AWS/GCP/Azure calls.
- If AWS APIs are used, they are routed to **LocalStack** (`http://localhost:4566`) only.
- Do not use real cloud credentials.

## Standardized layout (Phase 1)
- `app/` — provided service source code.
- `docker/` — Dockerfile + docker notes for local build/run.
- `k8s/` — Kubernetes manifests (devops namespace + app + Jenkins ingress/service/deploy scaffolding).
- `jenkins/` — Jenkins pipeline files for A/B/C.
- `iac/` — LocalStack-oriented Terraform scaffolding.
- `scripts/` — helper scripts (kind, registry, ingress, tls, deploy, verify).
- `evidence/` — where screenshots/logs are stored.
- `docs/` — architecture, runbook, and evidence checklist.

Legacy folders (`task-*`, `terraform/`, `helm/`, `.github/workflows/`) are intentionally kept and not deleted.

---

## Requirement → File(s) mapping

| Assignment requirement | File(s) in repo |
|---|---|
| A) IaC for cluster + infra | `iac/terraform/providers.tf`, `iac/terraform/main.tf`, `iac/terraform/variables.tf`, `iac/terraform/outputs.tf`, `iac/terraform/README.md` |
| B) Dockerfile for service | `docker/Dockerfile`, `docker/.dockerignore`, `docker/README.md`, `app/` |
| C1) Pipeline A (merge-main, build/push/deploy devops) | `jenkins/Jenkinsfile.A`, `jenkins/README.md`, `k8s/app/*` |
| C2) Pipeline B (replicas + image tag) | `jenkins/Jenkinsfile.B`, `jenkins/README.md`, `k8s/app/deployment.yaml` |
| C3) Pipeline C (inject file content into pod fs) | `jenkins/Jenkinsfile.C`, `jenkins/README.md` |
| D) HTTPS-only (app + Jenkins) | `k8s/app/ingress.yaml`, `k8s/jenkins/ingress.yaml`, `scripts/setup-tls.sh` |
| E) Evidence (logs/screenshots/API proof) | `docs/EVIDENCE_CHECKLIST.md`, `evidence/screenshots/`, `evidence/logs/` |
| F) Security best practices | `docs/ARCHITECTURE.md`, `TASKS.md` (security checklist) |

---

## Quick navigation
- Execution order: `docs/RUNBOOK.md`
- Architecture: `docs/ARCHITECTURE.md`
- Evidence capture list: `docs/EVIDENCE_CHECKLIST.md`
- Master checklist: `TASKS.md`

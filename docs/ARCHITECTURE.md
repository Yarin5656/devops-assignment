# ARCHITECTURE.md — Local-Only Assignment Architecture

## Selected stack (proposed)
- Kubernetes: **kind**
- Jenkins: **inside Kubernetes** (namespace `jenkins`)
- Private registry: **local registry (`registry:2`)**
- AWS simulation (IaC requirement): **LocalStack** (Terraform provider local endpoints)
- HTTPS-only: **NGINX Ingress + self-signed TLS**

## Why this choice
- kind is lightweight, deterministic, and scriptable in WSL.
- Jenkins in k8s avoids split-network complexity and is closer to production.
- local `registry:2` is simpler and more reliable than emulated ECR for fast CI loops.
- LocalStack still satisfies AWS/IaC simulation requirement without real cloud calls.

## Text diagram
```text
Git repo (this repo)
  ├─ Jenkins Pipeline A/B/C
  │    ├─ build app image
  │    ├─ push to local private registry (registry:2)
  │    └─ deploy/patch k8s resources in namespace devops
  │
  ├─ kind Kubernetes cluster
  │    ├─ namespace: devops
  │    │    ├─ Deployment + Service
  │    │    └─ Ingress (TLS-only)
  │    └─ namespace: jenkins
  │         └─ Jenkins + Ingress (TLS-only)
  │
  └─ Terraform (LocalStack mode)
       └─ simulated AWS resources via http://localhost:4566
```

## Security defaults (target)
- Non-root app container where feasible
- K8s secrets templates, no plaintext secrets in git
- Minimal RBAC for Jenkins service account
- HTTPS ingress + redirect from HTTP

# RUNBOOK.md — Local-Only Execution Order (WSL Ubuntu)

> Scope: local machine only. No real cloud endpoints.

## 0) Prerequisites
Install and verify:

```bash
docker --version
kubectl version --client
kind --version
helm version
terraform version
openssl version
```

Add local hosts entries:

```bash
# /etc/hosts
127.0.0.1 app.local
127.0.0.1 jenkins.local
```

## 1) Bootstrap local cluster and ingress
```bash
bash scripts/setup-kind.sh
bash scripts/setup-ingress.sh
kubectl get nodes
```

## 2) Setup private local registry
```bash
bash scripts/setup-registry.sh
```

Expected image naming convention:
- `localhost:5001/devops-app:<tag>`

## 3) Build and smoke-test app image
```bash
docker build -f docker/Dockerfile -t localhost:5001/devops-app:local .
docker run --rm -p 8080:8080 localhost:5001/devops-app:local
# in another terminal:
curl -sS http://localhost:8080/
```

## 4) TLS assets (self-signed for local)
```bash
bash scripts/setup-tls.sh
```

## 5) Deploy Kubernetes resources
```bash
kubectl apply -f k8s/namespace-devops.yaml
kubectl apply -k k8s/app
kubectl apply -k k8s/jenkins
```

## 6) Verify HTTPS-only routes
```bash
curl -kI https://app.local
curl -kI https://jenkins.local
curl -I http://app.local
curl -I http://jenkins.local
```

HTTP should redirect to HTTPS once ingress rules are fully implemented.

## 7) Jenkins pipelines A/B/C
Import and run:
- `jenkins/Jenkinsfile.A`
- `jenkins/Jenkinsfile.B`
- `jenkins/Jenkinsfile.C`

## 8) Collect evidence
- Follow `docs/EVIDENCE_CHECKLIST.md`
- Store artifacts in:
  - `evidence/screenshots/`
  - `evidence/logs/`

## LocalStack / Terraform safety notes
- Terraform path: `iac/terraform`
- Endpoint must remain: `http://localhost:4566`
- Never point provider to real AWS endpoints.

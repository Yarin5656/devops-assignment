# TASKS.md — AUI DevOps Assignment 2024 (Local-Only Master Checklist)

## Constraints (must keep)
- [ ] No real cloud calls (AWS only via LocalStack endpoint `http://localhost:4566`)
- [ ] Work only inside this repo
- [ ] No destructive commands without approval
- [ ] No secret values committed

---

## MVP path (minimum to pass)

### A) IaC + platform
- [ ] Terraform profile for **LocalStack** provider/endpoints (safe local mode)
- [ ] Local Kubernetes bootstrap scripts (kind cluster + ingress + namespace `devops`)
- [ ] Optional LocalStack ECR emulation wiring (documented)

### B) App container
- [ ] Dockerfile for provided service is valid and runnable locally
- [ ] Local smoke test (`docker run` + `curl`) documented

### C) Jenkins pipelines (A/B/C)
- [ ] Pipeline A: trigger on merge to `main` path (simulated in local Jenkins), build image, push to private registry, deploy to `devops`
- [ ] Pipeline B: Jenkins params for replica count + image tag update in same run
- [ ] Pipeline C: Jenkins param injects file content into pods filesystem (ConfigMap/secret+mount approach)

### D) HTTPS-only
- [ ] App exposed with TLS ingress only
- [ ] Jenkins exposed with TLS ingress only
- [ ] HTTP→HTTPS redirect enforced

### E) Evidence
- [ ] k8s manifests / Helm / Jenkins pipeline files committed
- [ ] At least one successful run log per pipeline (A/B/C)
- [ ] Screenshots checklist completed
- [ ] REST API proof (`curl -k https://...`) captured

---

## Production-like path (better quality)
- [ ] Non-root containers + read-only root FS where practical
- [ ] Liveness/readiness probes + resource requests/limits
- [ ] Least-privilege service accounts/RBAC for Jenkins deploy actions
- [ ] Secrets templates + no plaintext secret output in logs
- [ ] Deterministic scripts for full rebuild from clean machine
- [ ] Signed/tagged image strategy + immutable tags

---

## Bonus items
- [ ] Local observability addon (Prometheus/Grafana lightweight)
- [ ] Policy checks (kubeconform/kube-linter/trivy)
- [ ] Optional real-cloud template docs (not executed), clearly separated from local mode
- [ ] Makefile targets for end-to-end automation

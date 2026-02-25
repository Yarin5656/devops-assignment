# TASKS.md — Master Checklist (AUI DevOps Assignment 2024)

## Current repo map (quick)
- `terraform/` — main AWS IaC (VPC, IAM, EKS, ECR) + `bootstrap/` for S3 backend + DynamoDB lock.
- `app/` — Flask app + Dockerfile.
- `helm/` — Helm chart for Kubernetes deployment/service.
- `.github/workflows/` — CI validate + Terraform apply + app deploy workflows.
- `task-2/` — local LocalStack/PostGIS ingest pipeline assignment.
- `task-3/` — HA cluster + Jenkins monitor lab assignment.
- `task-4/` — currently mostly environment/cache artifacts; no clear deliverable files.
- `task-5/` — Jenkins monorepo CI assignment (single Jenkinsfile + 3 services).

---

## Requirement-to-repo mapping

### IaC (Terraform)
- ✅ Present in `terraform/` and `terraform/modules/*`.
- ✅ Includes VPC, public/private subnets, EKS, 2 node groups, ECR, IAM roles.
- ✅ Includes bootstrap backend infra (`terraform/bootstrap/`) for S3 + DynamoDB locking.
- ✅ Outputs exist (`terraform/outputs.tf`) for cluster name/endpoint, ECR URL, IAM ARNs, subnet/VPC IDs.

### Dockerfile
- ✅ Present: `app/Dockerfile`.
- ⚠️ Runs Flask directly (acceptable for MVP, not hardened prod).

### Jenkins pipelines A/B/C
- ✅ Jenkins artifacts exist for separate tasks:
  - `task-3` (Jenkins monitor job)
  - `task-5/Jenkinsfile` (CI pipeline)
- ❌ No explicit A/B/C pipeline structure or naming in root assignment docs.
- ❌ No single integration document proving A/B/C mapping and run evidence.

### Kubernetes manifests / deployment
- ✅ Helm chart exists (`helm/` templates).
- ❌ Chart defaults are not aligned to app:
  - image defaults to `nginx:latest` (not app image)
  - service type `ClusterIP` (not internet exposed)
  - container/service port is 80 while app listens on 8080

### HTTPS-only
- ❌ Missing (no TLS ingress/cert-manager/ALB TLS config).
- ❌ No redirect from HTTP→HTTPS defined.

### GitHub Actions build+deploy on push to main
- ⚠️ Partial:
  - `ci-validate.yml` runs on push/pr.
  - `deploy.yml` exists but is `workflow_dispatch` only (not push to main).
- ✅ Bonus Terraform workflow exists (`terraform-apply.yml`) but also manual dispatch.

---

## Gaps to complete assignment (specific)
1. Fix Helm chart defaults to deploy the Flask app correctly (image/port/service exposure).
2. Ensure app is internet-accessible from EKS (LoadBalancer or Ingress+ALB).
3. Implement HTTPS-only path (TLS cert + enforce redirect).
4. Make app deploy workflow run automatically on push to `main` (with safe branch filter/path filter).
5. Add clear runbook evidence in README:
   - terraform apply
   - ECR login/build/push
   - kubeconfig setup
   - helm upgrade/install
   - how to fetch public URL
6. Clarify Jenkins A/B/C mapping (if required by your evaluator) in one short section with file pointers.
7. Clean/ignore environment artifacts (especially `task-4` local virtualenv/cache) to reduce repo noise.

---

## MVP path (minimum to pass)
- [ ] Helm values/templates aligned to Flask app (repo/tag/port=8080).
- [ ] Kubernetes exposure via `Service type=LoadBalancer` (or working Ingress).
- [ ] GitHub Actions deploy on push to `main` (build+push ECR + helm upgrade).
- [ ] README updated with exact end-to-end commands and required secrets.
- [ ] Verify required Terraform outputs are documented and retrievable.

## Production-like path (better quality)
- [ ] Use Ingress (AWS Load Balancer Controller) with ACM certificate.
- [ ] Enforce HTTPS-only (redirect 80→443).
- [ ] Pin image tags (SHA) and avoid mutable defaults.
- [ ] Add health probes/resources/securityContext in Helm deployment.
- [ ] Use GitHub OIDC role assumption instead of long-lived AWS keys.
- [ ] Add rollback-safe deployment flags (`--atomic --timeout`) and basic smoke test step.

## Bonus items
- [ ] Terraform GitHub Action with `fmt/validate/plan` on PR and gated apply on main.
- [ ] Basic monitoring stack (e.g., kube-prometheus-stack or lightweight metrics/logging).
- [ ] Add artifact/report section showing Jenkins task pipelines (A/B/C mapping if required).
- [ ] Cost controls: autoscaling bounds, cleanup instructions, optional destroy workflow.

# jenkins/

Assignment pipeline files:
- `Jenkinsfile.A` — CI/CD on merge-to-main model
- `Jenkinsfile.B` — scale replicas + update image tag
- `Jenkinsfile.C` — inject file content into pod filesystem

## Notes
- These are Phase-1 scaffolds.
- Actual kubectl/helm commands and credentials handling are implemented in Phase 4.
- Jenkins should be exposed HTTPS-only via `k8s/jenkins/ingress.yaml`.

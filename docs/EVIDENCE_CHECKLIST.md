# EVIDENCE_CHECKLIST.md — What to Capture

## Pipelines
- [ ] Pipeline A successful run log (build + push + deploy)
- [ ] Pipeline B successful run log (`REPLICAS` + `IMAGE_TAG` update)
- [ ] Pipeline C successful run log (file injection parameter)

## Kubernetes resources
- [ ] `kubectl get ns` showing `devops` and `jenkins`
- [ ] `kubectl get deploy,svc,ingress -A`
- [ ] `kubectl describe ingress -n devops`
- [ ] `kubectl get secret -n devops` (TLS secret exists)

## HTTPS proof
- [ ] `curl -k https://app.local/...` success output
- [ ] `curl -k https://jenkins.local/login` success output
- [ ] HTTP redirect proof (`curl -I http://app.local` returns 301/308 to https)

## Registry proof
- [ ] image exists in private local registry (tag list or pull success)

## IaC / LocalStack proof
- [ ] Terraform plan/apply output in LocalStack mode (or equivalent local apply logs)
- [ ] LocalStack resources listed via local endpoint commands

## Screenshots
- [ ] Jenkins dashboard with A/B/C jobs
- [ ] Pipeline run success page for each pipeline
- [ ] k8s resources view (terminal screenshot acceptable)
- [ ] app endpoint in browser over HTTPS
- [ ] jenkins endpoint in browser over HTTPS

## API / REST proof
- [ ] at least one successful REST call to app endpoint (HTTPS)
- [ ] if app has additional API routes, include request/response examples

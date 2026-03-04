# IMPROVEMENTS.md

Practical roadmap to move from assignment-grade to production-grade.

## Priority 1 (high impact)
- Add structured logging (JSON) with request IDs.
- Add integration tests for online/offline modes.
- Add API response schemas for error payload consistency.
- Add stricter lint/format gates (ruff + black + mypy).

## Priority 2 (platform hardening)
- Harden Docker image (non-root user, read-only FS, minimal base, healthcheck).
- Add k8s resource requests/limits and pod security context.
- Add network policy and namespace isolation.
- Add readiness startup tuning for slower environments.

## Priority 3 (delivery quality)
- Add semantic versioning + changelog automation.
- Publish Helm chart package from CI.
- Add release workflow with tagged Docker images.
- Add OpenAPI examples and Postman collection.

## Priority 4 (observability)
- Add Prometheus metrics endpoint.
- Add basic dashboards and alerting rules.
- Capture p95 latency and upstream failure rate.

## Priority 5 (resilience)
- Add circuit breaker or fallback cache for upstream outages.
- Add configurable retry/backoff via env vars.
- Optional background prefetch cache for faster `/characters` responses.

# Observability Guide

## Overview

Three pillars implemented for the URL Shortener:

| Pillar | Tool | Access |
|--------|------|--------|
| Metrics | Prometheus + Grafana | `localhost:9090` / `localhost:3000` |
| Logs | Structured JSON → Loki / EFK | `localhost:3100` (Loki) |
| Traces | (future) OpenTelemetry → Tempo | — |

---

## Metrics

### Exposed Metrics (Prometheus format)

The app exposes metrics at `GET /metrics`.

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `http_requests_total` | Counter | `method`, `endpoint`, `status_code` | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | `method`, `endpoint` | Request latency |
| `url_shorten_total` | Counter | — | Total URLs shortened |
| `url_resolve_total` | Counter | `result` (hit/miss) | Resolve attempts |

### Sample queries (PromQL)

```promql
# Request rate (last 5 min)
rate(http_requests_total[5m])

# Error rate (5xx)
rate(http_requests_total{status_code=~"5.."}[5m])

# p99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Cache hit rate
rate(url_resolve_total{result="hit"}[5m]) /
  rate(url_resolve_total[5m])
```

### Prometheus scrape config

The pod annotations already configure scraping:
```yaml
prometheus.io/scrape: "true"
prometheus.io/port:   "8000"
prometheus.io/path:   "/metrics"
```

If you use the Prometheus Operator, add a `ServiceMonitor`:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: url-shortener
  namespace: url-shortener-staging
spec:
  selector:
    matchLabels:
      app: url-shortener
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

### Local Prometheus + Grafana (docker-compose addon)

Add to `docker-compose.yml` for full local observability stack:

```yaml
  prometheus:
    image: prom/prometheus:v2.52.0
    volumes:
      - ./infra/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:10.4.0
    ports: ["3000:3000"]
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
```

`infra/prometheus/prometheus.yml`:
```yaml
scrape_configs:
  - job_name: url-shortener
    static_configs:
      - targets: ['app:8000']
    metrics_path: /metrics
```

---

## Structured Logging

The app emits JSON logs to stdout:

```json
{
  "timestamp": "2024-01-15T10:00:00",
  "level": "INFO",
  "logger": "main",
  "message": "{\"event\": \"shorten\", \"code\": \"abc123\", \"url\": \"https://example.com\"}",
  "module": "main",
  "line": 95
}
```

### Centralized logging options

#### Option A: Loki + Promtail (lightweight, recommended for kind)
```bash
# Promtail reads container logs and ships to Loki
helm install loki grafana/loki-stack -n monitoring --create-namespace
```

Query in Grafana:
```logql
{namespace="url-shortener-staging"} | json | event="shorten"
```

#### Option B: EFK (Elasticsearch + Fluentd + Kibana)
```bash
# Full EFK stack (heavier, ~4GB RAM)
helm install efk elastic/eck-stack -n logging --create-namespace
```

---

## Alerting Rules (Prometheus)

```yaml
# infra/prometheus/alerts.yaml
groups:
  - name: url-shortener
    rules:
      - alert: HighErrorRate
        expr: |
          rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Error rate > 5% for 2 minutes"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "p99 latency > 1s"

      - alert: PodNotReady
        expr: kube_pod_status_ready{namespace=~"url-shortener.*"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Pod not ready in {{ $labels.namespace }}"
```

---

## Grafana Dashboard

Import dashboard ID **12740** (FastAPI / Prometheus default) or create custom:

Key panels:
- **RPS** by endpoint
- **Error rate** (4xx/5xx split)
- **p50/p95/p99 latency**
- **Shorten rate** vs **Resolve rate**
- **Pod CPU/Memory** (via kube-state-metrics)

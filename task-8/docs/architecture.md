# Architecture Overview

## System Components

```
┌─────────────────────────────────────────────────────────────────────┐
│  Local Development (docker-compose)                                  │
│                                                                      │
│  ┌─────────────┐   ┌───────────┐   ┌──────────────────────────┐    │
│  │  FastAPI App │   │   Redis   │   │  LocalStack              │    │
│  │  :8000       │   │  :6379    │   │  :4566                   │    │
│  │  /shorten    │   │ (future   │   │  SecretsManager          │    │
│  │  /resolve    │   │  storage) │   │  SSM / S3                │    │
│  │  /healthz    │   │           │   │  (AWS API emulation)     │    │
│  │  /metrics    │   └───────────┘   └──────────────────────────┘    │
│  └─────────────┘                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  kind Cluster (local Kubernetes)                                     │
│                                                                      │
│  ┌───────────────────────────────┐  ┌────────────────────────────┐  │
│  │  Namespace: url-shortener-    │  │  Namespace: url-shortener- │  │
│  │            staging            │  │            production      │  │
│  │                               │  │                            │  │
│  │  Deployment (1 replica)       │  │  Deployment (3 replicas)   │  │
│  │  ┌─────────────────────────┐  │  │  ┌──────────────────────┐  │  │
│  │  │ url-shortener pod       │  │  │  │ pod 1  pod 2  pod 3  │  │  │
│  │  │ ├ main.py               │  │  │  └──────────────────────┘  │  │
│  │  │ ├ ConfigMap env         │  │  │  HPA (3-10 replicas)       │  │
│  │  │ └ Secret (optional)     │  │  │  PDB (minAvailable: 2)     │  │
│  │  └─────────────────────────┘  │  └────────────────────────────┘  │
│  │  Service (ClusterIP :80)      │  Service (ClusterIP :80)         │
│  └───────────────────────────────┘                                  │
│                                                                      │
│  Local Registry: localhost:5001 (kind-registry container)           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│  CI/CD Pipeline (GitHub Actions)                                     │
│                                                                      │
│  PR      → lint → test → trivy scan (no push)                       │
│                                                                      │
│  develop → lint → test → scan → build → push → deploy staging       │
│  push                                         ─────────────────►    │
│                                                                      │
│  tag     → lint → test → scan → build → push → [manual approval]    │
│  v*.*.*                                       ──────────────────►   │
│                                               deploy production      │
└─────────────────────────────────────────────────────────────────────┘
```

## Application Architecture

```
HTTP Request
     │
     ▼
FastAPI (uvicorn)
     │
     ├── Middleware: metrics + access log (every request)
     │
     ├── GET  /healthz   → HealthResponse {status, version}
     ├── POST /shorten   → ShortenResponse {code, short_url}
     │        │
     │        └── URLStorage.save(code, url)
     │                   │
     │                   └── InMemoryStorage (swap to RedisStorage here)
     │
     ├── POST /resolve   → ResolveResponse {url} or 404
     │        │
     │        └── URLStorage.get(code)
     │
     └── GET  /metrics   → Prometheus text format
```

## Storage Abstraction

```python
# Current: InMemoryStorage (zero deps, zero cost)
# Future:  RedisStorage    (uncomment REDIS_URL env var)
#          PostgresStorage (full persistence + analytics)

class URLStorage(ABC):
    def save(self, code: str, url: str) -> None: ...
    def get(self, code: str) -> Optional[str]: ...
    def exists(self, code: str) -> bool: ...
```

Swap is made in `main.py` line `_storage: URLStorage = InMemoryStorage()`.
No other code changes required.

## Data Flow

```
POST /shorten
  Body: {"url": "https://example.com"}
    │
    ├── Validate URL (Pydantic HttpUrl)
    ├── Generate 6-char random code (base62: a-z A-Z 0-9)
    ├── Check uniqueness (retry on collision)
    ├── storage.save(code, url)
    ├── Increment SHORTEN_COUNT metric
    └── Return: {"code": "aB3xYz", "short_url": "http://base-url/aB3xYz"}

POST /resolve
  Body: {"code": "aB3xYz"}
    │
    ├── storage.get(code)
    ├── 404 if not found (RESOLVE_COUNT result=miss)
    └── Return: {"url": "https://example.com"} (RESOLVE_COUNT result=hit)
```

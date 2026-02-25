# Rick and Morty Assignment (FastAPI + CSV + DevOps Bonus)

Local, GitHub-ready solution using **Python 3.11** + **FastAPI**.

## What it does
- Fetches all pages from Rick and Morty API.
- Filters characters where:
  - `species == "Human"`
  - `status == "Alive"`
  - `origin.name == "Earth"` (exact match)
- Returns fields:
  - `name`
  - `location` (from `character.location.name`)
  - `image` (URL)
- Exposes REST endpoints and CSV export.

## Project structure
```text
app/
  main.py
  models.py
  services/rickmorty.py
  utils/csv_writer.py
yamls/
  deployment.yaml
  service.yaml
  ingress.yaml
helm/rickmorty-service/
  Chart.yaml
  values.yaml
  templates/*
.github/workflows/ci.yml
data/
  output.csv (generated)
tests/
requirements.txt
Dockerfile
```

## Running locally (Python)
```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

If `python3.11` is not installed, use `python3`.

## Running with Docker
Build:
```bash
docker build -t rickmorty-fastapi:local .
```

Run:
```bash
docker run --rm -p 8000:8000 rickmorty-fastapi:local
```

Run in offline fixture mode (deterministic, no external API calls):
```bash
docker run --rm -e RM_OFFLINE=1 -p 8000:8000 rickmorty-fastapi:local
```

## API endpoints
- `GET /healthcheck`
- `GET /characters`
- `GET /characters/export-csv`

### Example curl commands
```bash
curl -s http://127.0.0.1:8000/healthcheck
curl -s http://127.0.0.1:8000/characters | jq '.[0:5]'
curl -s http://127.0.0.1:8000/characters/export-csv
```

CSV is written to:
- `data/output.csv`

## Kubernetes deployment (yamls)
> Assumes a running Kubernetes cluster and ingress controller.

```bash
kubectl apply -f yamls/deployment.yaml
kubectl apply -f yamls/service.yaml
kubectl apply -f yamls/ingress.yaml

kubectl get deploy,svc,ingress
```

### Notes
- Deployment uses probes on `/healthcheck`.
- Service is `ClusterIP` on port 80 -> container 8000.
- Ingress host default: `rickmorty.local`.

## Helm deployment
```bash
helm upgrade --install rickmorty-service ./helm/rickmorty-service \
  --set image.repository=rickmorty-fastapi \
  --set image.tag=local
```

Override ingress host if needed:
```bash
helm upgrade --install rickmorty-service ./helm/rickmorty-service \
  --set ingress.host=rickmorty.local
```

## GitHub Actions workflow overview
Primary workflow file: `.github/workflows/ci.yml`

### Triggers
- `push` to `main`
- `pull_request` targeting `main`

### What CI verifies
Job 1 (`test-and-docker-smoke`):
1. Checkout repo
2. Setup Python 3.11
3. Install dependencies
4. Run unit tests
5. Build Docker image
6. Run container and execute smoke tests via `scripts/smoke_test.sh`

Job 2 (`kind-k8s-smoke`):
1. Build Docker image
2. Create local Kubernetes cluster using kind
3. Load image into kind
4. Apply `yamls/` manifests
5. Port-forward service and run same smoke tests

Notes:
- Smoke tests validate `/healthcheck`, `/characters`, and `/characters/export-csv`.
- CI is local-runner only (no paid external services).
- CI runs the app with `RM_OFFLINE=1` so tests are deterministic and not affected by upstream API rate limits.

## Offline fixture mode (`RM_OFFLINE=1`)
To make CI stable and deterministic, the app supports an offline mode:
- When `RM_OFFLINE=1`, character data is loaded from `data/fixtures_characters.json`
- The same filtering logic is used (`Human` + `Alive` + `origin == Earth`)
- `/characters` and `/characters/export-csv` both use fixture data in this mode

Normal mode (default) still calls the real Rick and Morty API.

If upstream returns HTTP 429 in normal mode, the API responds with:
- `503 Service Unavailable`
- clear message: `Upstream API is rate-limited. Please retry shortly.`

## Run tests locally
```bash
python -m unittest discover -s tests -v
```

## Notes
- Uses `httpx` with timeout and robust error handling.
- Pagination is handled via `info.next` until exhausted.
- Bonus k8s and Helm are included and values-driven.

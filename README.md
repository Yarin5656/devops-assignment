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
.github/workflows/rickmorty-ci.yml
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
Workflow file: `.github/workflows/rickmorty-ci.yml`

Pipeline steps:
1. Checkout repo
2. Setup Python 3.11
3. Install dependencies
4. Run unit tests
5. Build Docker image
6. Start container and run smoke checks (`/healthcheck`, `/characters`)
7. Cleanup container

## Run tests locally
```bash
python -m unittest discover -s tests -v
```

## Notes
- Uses `httpx` with timeout and robust error handling.
- Pagination is handled via `info.next` until exhausted.
- Bonus k8s and Helm are included and values-driven.

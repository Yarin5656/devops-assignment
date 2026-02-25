# docker/

Local app container artifacts for the AUI assignment.

## Build
```bash
docker build -f docker/Dockerfile -t localhost:5001/devops-app:local .
```

## Run
```bash
docker run --rm -p 8080:8080 localhost:5001/devops-app:local
curl -sS http://localhost:8080/
```

> This folder is Phase-1 scaffolding. Hardening (non-root, healthcheck, minimal runtime) is handled in later phases.

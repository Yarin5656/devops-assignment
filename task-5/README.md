# DevOps Task (CI-Focused) - Jenkins Monorepo CI Pipeline

## Repository structure

```text
task-5/
├── Jenkinsfile
├── README.md
├── Makefile
├── shared/
│   └── ci/
│       ├── lint.sh
│       ├── test.sh
│       ├── scan.sh
│       └── build.sh
├── user-service/
│   ├── Dockerfile
│   ├── package.json
│   ├── .eslintrc.json
│   ├── app.js
│   ├── server.js
│   └── app.test.js
├── transaction-service/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── requirements-dev.txt
│   ├── .flake8
│   ├── app/
│   │   ├── __init__.py
│   │   └── main.py
│   └── tests/
│       └── test_main.py
└── notification-service/
    ├── Dockerfile
    ├── go.mod
    ├── .golangci.yml
    ├── main.go
    └── main_test.go
```

## Run services locally

### user-service (Node.js)

```bash
cd user-service
npm install
npm start
```

Health endpoint: `http://localhost:3000/health`

### transaction-service (FastAPI)

```bash
cd transaction-service
python3 -m pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Health endpoint: `http://localhost:8000/health`

### notification-service (Go)

```bash
cd notification-service
go run .
```

Health endpoint: `http://localhost:8080/health`

## Local CI commands

Use the shared scripts directly:

```bash
bash shared/ci/lint.sh user-service
bash shared/ci/test.sh transaction-service
bash shared/ci/scan.sh notification-service
bash shared/ci/build.sh user-service ci-local
```

Or use `Makefile`:

```bash
make lint SERVICE=user-service
make test SERVICE=transaction-service
make scan SERVICE=notification-service
make build SERVICE=user-service TAG=ci-local
```

## Jenkins pipeline behavior

The pipeline is defined in `Jenkinsfile` and is intended for Linux agents.

1. Branch gate: runs only for push/PR targeting `main` or `develop`.
2. Detect changes:
   - Detects changed files via `git diff`.
   - For PR builds: compares against `origin/$CHANGE_TARGET`.
   - For branch builds: compares against `GIT_PREVIOUS_SUCCESSFUL_COMMIT` (fallback `HEAD~1`).
   - Runs CI only for changed service directories.
   - If `shared/` changed, all services run.
3. Parallel per-service CI:
   - Lint (`eslint`, `flake8`, `golangci-lint`)
   - Test (`jest`, `pytest`, `go test`) with retry.
   - Security scan (`gitleaks`, `npm audit`, `bandit`, `go vet`)
4. Docker build (parallel):
   - Builds only changed services.
   - Image tag format: `ci-${GIT_COMMIT.take(7)}`.
   - Docker push is optional and env-configurable.
5. Manual approval: `Ready to deploy` stage (pipeline stops there; no CD).
6. Notifications:
   - Sends success/failure webhook to Slack/MS Teams (credential-backed URL).

### Pipeline diagram

```mermaid
flowchart TD
    A[Push or PR to main/develop] --> B[Branch Gate]
    B --> C[Detect Changed Services]
    C -->|shared changed| D[Run CI for all services]
    C -->|service folders changed| E[Run CI for changed services only]
    D --> F[Parallel service CI]
    E --> F
    F --> G[Parallel Docker Build]
    G --> H[Manual Input: Ready to deploy]
    H --> I[Stop (No CD)]
    F --> J[Publish JUnit + Coverage + Security Artifacts]
    I --> K[Success/Failure Webhook]
```

## Jenkins credentials and environment configuration

No secrets are hardcoded. Configure through Jenkins credentials and environment variables.

### Required Jenkins credential IDs (as env vars)

- `NOTIFICATION_WEBHOOK_CREDENTIALS_ID` (Secret text): Slack/MS Teams webhook URL.
- `DOCKERHUB_CREDENTIALS_ID` (Username + password): used when `REGISTRY_PROVIDER=dockerhub` and `PUSH_IMAGES=true`.
- `AWS_CREDENTIALS_ID` (AWS credentials): used when `REGISTRY_PROVIDER=ecr` and `PUSH_IMAGES=true`.

### Additional environment variables

- `PUSH_IMAGES` (`true` or `false`)
- `REGISTRY_PROVIDER` (`dockerhub` or `ecr`)
- `REGISTRY_NAMESPACE` (e.g. org/user name)
- `DOCKER_REGISTRY` (optional custom registry host/prefix)
- `AWS_REGION` (required for ECR push)
- `AWS_ACCOUNT_ID` (required for ECR push)

## Notes on tool availability in Jenkins

Shared scripts install missing tools when possible:

- `gitleaks` is downloaded in `shared/ci/scan.sh` if not preinstalled.
- `golangci-lint` is installed via `go install` if missing.
- `go-junit-report` is installed best-effort for Go JUnit output.

## Example screenshots checklist (optional)

- [ ] Jenkins pipeline run summary
- [ ] Detect changed services log output
- [ ] Parallel stage view (per service)
- [ ] JUnit report published
- [ ] Coverage artifact archive
- [ ] Security scan artifact archive
- [ ] Manual approval stage shown
- [ ] Notification delivery (Slack/Teams)

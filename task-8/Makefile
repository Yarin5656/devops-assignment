# =============================================================================
# Makefile – Developer convenience targets for URL Shortener
#
# Prerequisites: Python 3.12+, Docker, make (Git Bash on Windows)
#
# Usage:
#   make install    # install dev dependencies
#   make lint       # run ruff linter
#   make test       # run pytest with coverage
#   make build      # build Docker image locally
#   make up         # start docker-compose stack
#   make down       # stop docker-compose stack
#   make scan       # run Trivy vulnerability scan on local image
#   make kind-up    # create a local kind cluster
#   make deploy-staging   # deploy to local staging namespace
# =============================================================================

SHELL       := /bin/bash
APP_DIR     := app
IMAGE_NAME  := url-shortener
IMAGE_TAG   ?= local
REGISTRY    ?= localhost:5001
FULL_IMAGE  := $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
K8S_STAGING := k8s/overlays/staging
K8S_PROD    := k8s/overlays/production
NAMESPACE_STAGING  := url-shortener-staging
NAMESPACE_PROD     := url-shortener-production
COVERAGE_MIN := 80

.PHONY: help install lint test test-ci build push up down \
        scan kind-up kind-down kind-load \
        deploy-staging deploy-production rollback \
        localstack-init clean

# Default target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

install: ## Install Python dev dependencies
	pip install --upgrade pip
	pip install -r $(APP_DIR)/requirements.txt

lint: ## Run ruff linter + formatter check
	cd $(APP_DIR) && ruff check . && ruff format --check .

lint-fix: ## Auto-fix lint issues
	cd $(APP_DIR) && ruff check --fix . && ruff format .

test: ## Run tests with coverage report
	cd $(APP_DIR) && \
	pytest tests/ -v \
	  --cov=. \
	  --cov-report=term-missing \
	  --cov-report=xml:coverage.xml \
	  --cov-fail-under=$(COVERAGE_MIN)

test-ci: ## Run tests in CI mode (JUnit XML output)
	cd $(APP_DIR) && \
	pytest tests/ -v \
	  --cov=. \
	  --cov-report=xml:coverage.xml \
	  --cov-fail-under=$(COVERAGE_MIN) \
	  --junitxml=test-results.xml

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

build: ## Build Docker image (local tag)
	docker build \
	  --build-arg APP_VERSION=$(IMAGE_TAG) \
	  -t $(IMAGE_NAME):$(IMAGE_TAG) \
	  -t $(IMAGE_NAME):latest \
	  .

build-prod: ## Build with semver + SHA tags (set VERSION and SHA env vars)
	@[ -n "$(VERSION)" ] || (echo "❌ VERSION is not set. Usage: make build-prod VERSION=1.2.3 SHA=abc1234"; exit 1)
	@[ -n "$(SHA)" ]     || (echo "❌ SHA is not set.";     exit 1)
	docker build \
	  --build-arg APP_VERSION=$(VERSION)-$(SHA) \
	  -t $(IMAGE_NAME):$(VERSION) \
	  -t $(IMAGE_NAME):$(VERSION)-$(SHA) \
	  -t $(IMAGE_NAME):latest \
	  .

push: build ## Push image to local registry (kind)
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(FULL_IMAGE)
	docker push $(FULL_IMAGE)

up: ## Start full local stack (app + redis + localstack)
	docker compose up -d
	@echo "✅ App:        http://localhost:8000"
	@echo "✅ Docs:       http://localhost:8000/docs"
	@echo "✅ Metrics:    http://localhost:8000/metrics"
	@echo "✅ LocalStack: http://localhost:4566"

down: ## Stop local stack
	docker compose down

down-v: ## Stop local stack and remove volumes
	docker compose down -v

logs: ## Follow app logs
	docker compose logs -f app

# ---------------------------------------------------------------------------
# Security scan (Trivy)
# ---------------------------------------------------------------------------

scan: build ## Scan image for vulnerabilities with Trivy (CRITICAL+HIGH)
	@command -v trivy >/dev/null 2>&1 || \
	  (echo "Installing Trivy..." && \
	   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin)
	trivy image \
	  --exit-code 1 \
	  --severity CRITICAL,HIGH \
	  --no-progress \
	  $(IMAGE_NAME):$(IMAGE_TAG)

scan-table: build ## Scan image, print table (no exit-code gate)
	trivy image --severity CRITICAL,HIGH --no-progress $(IMAGE_NAME):$(IMAGE_TAG) || true

# ---------------------------------------------------------------------------
# kind – local Kubernetes cluster
# ---------------------------------------------------------------------------

kind-up: ## Create a local kind cluster with local registry
	./scripts/setup-kind.sh

kind-down: ## Delete the kind cluster
	kind delete cluster --name url-shortener-local || true

kind-load: build ## Load image into kind cluster
	kind load docker-image $(IMAGE_NAME):$(IMAGE_TAG) --name url-shortener-local

# ---------------------------------------------------------------------------
# Kubernetes deployments (local kind)
# ---------------------------------------------------------------------------

deploy-staging: ## Deploy to staging namespace in kind cluster
	./scripts/deploy-staging.sh $(IMAGE_TAG)

deploy-production: ## Deploy to production namespace in kind cluster (manual gate)
	./scripts/deploy-production.sh $(IMAGE_TAG)

rollback: ## Rollback staging to previous revision
	kubectl rollout undo deployment/url-shortener -n $(NAMESPACE_STAGING)

rollback-prod: ## Rollback production to previous revision
	kubectl rollout undo deployment/url-shortener -n $(NAMESPACE_PROD)

# ---------------------------------------------------------------------------
# LocalStack (zero-cost AWS emulation)
# ---------------------------------------------------------------------------

localstack-init: ## Seed LocalStack with test secrets and S3 bucket
	./scripts/localstack-init.sh

# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

clean: ## Remove build artefacts
	find $(APP_DIR) -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find $(APP_DIR) -name "*.pyc" -delete 2>/dev/null || true
	rm -f $(APP_DIR)/coverage.xml $(APP_DIR)/test-results.xml || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true

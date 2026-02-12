# DevOps Assignment Portfolio Repo

This repo contains a complete DevOps stack:
- `terraform/`: AWS VPC + EKS + 2 node groups + ECR + IAM
- `terraform/bootstrap/`: S3 state bucket + DynamoDB lock table
- `app/`: Flask app and Dockerfile
- `helm/`: Helm chart (Service type `LoadBalancer`)
- `.github/workflows/`: CI validation + manual deploy workflows

## Safety First

- This repo is prepared for portfolio/demo usage.
- No secrets are committed.
- Deploy workflows are manual-only (`workflow_dispatch`).
- CI validation does not create cloud resources.

## Local Runbook (FREE)

Use this path to validate code and artifacts without creating AWS resources.

### Prerequisites

- Terraform `>= 1.5`
- Docker
- Helm
- Python 3.12+

### 1) Run the app locally

```bash
cd app
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Open `http://localhost:8080/`.

### 2) Build Docker image locally

```bash
docker build -t devops-assignment-app:local ./app
docker run --rm -p 8080:8080 devops-assignment-app:local
```

### 3) Validate Terraform locally (no backend, no apply)

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
```

### 4) Lint Helm chart locally

```bash
helm lint ./helm
helm template devops-app ./helm
```

### 5) GitHub CI behavior

Workflow `ci-validate.yml` runs on push/PR and executes:
- Terraform fmt check
- Terraform init with `-backend=false`
- Terraform validate
- Helm lint

## AWS Runbook (COST)

Use this path only when you intentionally want to provision resources.

### Cost-impacting resources

- EKS control plane
- EC2 worker nodes (2 node groups)
- NAT Gateway
- LoadBalancer service
- ECR storage
- S3 + DynamoDB for remote state

### 1) Bootstrap remote state (creates AWS resources)

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -out=tfplan-bootstrap
terraform -chdir=terraform/bootstrap apply tfplan-bootstrap
```

Capture outputs:

```bash
terraform -chdir=terraform/bootstrap output state_bucket_name
terraform -chdir=terraform/bootstrap output lock_table_name
```

### 2) Provision infrastructure (creates AWS resources)

```bash
terraform -chdir=terraform init \
  -backend-config="bucket=<STATE_BUCKET_NAME>" \
  -backend-config="key=devops-assignment/terraform.tfstate" \
  -backend-config="region=<AWS_REGION>" \
  -backend-config="dynamodb_table=<LOCK_TABLE_NAME>" \
  -backend-config="encrypt=true"

terraform -chdir=terraform plan -out=tfplan
terraform -chdir=terraform apply tfplan
```

### 3) Build and push to ECR

```bash
ECR_REPO=$(terraform -chdir=terraform output -raw ecr_repository_url)
AWS_REGION=<AWS_REGION>

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "${ECR_REPO%/*}"

docker build -t "$ECR_REPO:latest" ./app
docker push "$ECR_REPO:latest"
```

### 4) Configure kubeconfig and deploy with Helm

```bash
CLUSTER_NAME=$(terraform -chdir=terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

helm upgrade --install devops-app ./helm \
  --namespace devops-app \
  --create-namespace \
  --set image.repository="$ECR_REPO" \
  --set image.tag="latest"
```

Get public endpoint:

```bash
kubectl get svc -n devops-app
kubectl get svc devops-app-devops-app -n devops-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## GitHub Actions Workflows

- `ci-validate.yml`: automatic validation on push/PR (no resource creation).
- `deploy.yml`: manual build/push/deploy (`workflow_dispatch` only).
- `terraform-apply.yml`: manual Terraform apply (`workflow_dispatch` only).

## Required GitHub Secrets (names only)

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `EKS_CLUSTER_NAME`
- `ECR_REPOSITORY_URI`
- `TF_STATE_BUCKET`
- `TF_LOCK_TABLE`

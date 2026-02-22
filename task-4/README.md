# Task-4: DevOps Pipeline on AWS (FastAPI + Terraform + Jenkins)

## Architecture overview

- **App**: FastAPI service with two endpoints:
  - `GET /` -> exact plain text `Hello, DevOps!`
  - `POST /echo` -> returns received JSON body as-is
- **CI/CD**: Jenkins declarative pipeline in repo root (`Jenkinsfile`)
- **Infra**: Terraform in `infra/` creates a minimal AWS network and compute stack:
  - VPC with 2 public subnets across 2 AZs
  - Jenkins EC2 (Ubuntu)
  - App EC2 (Ubuntu Docker host)
  - Security groups for Jenkins/App (+ ALB SG if enabled)
  - Optional ALB on port 80
- **Deployment flow**:
  - Jenkins builds and pushes Docker image to Docker Hub
  - Jenkins deploys to App EC2 over SSH using `jenkins/deploy_app.sh`
  - Pipeline runs post-deploy health check

## Repository layout

```text
task-4/
??? app/
?   ??? __init__.py
?   ??? main.py
?   ??? tests/
?       ??? test_main.py
??? infra/
?   ??? backend.tf.example
?   ??? main.tf
?   ??? outputs.tf
?   ??? variables.tf
??? jenkins/
?   ??? deploy_app.sh
?   ??? install_app_host.sh
?   ??? install_jenkins.sh
?   ??? install_jenkins.sh.tftpl
??? .flake8
??? .gitignore
??? docker-compose.yml
??? Dockerfile
??? Jenkinsfile
??? Makefile
??? README.md
??? requirements.txt
```

## Local validation

Run from `task-4/`.

### 1) Python lint + tests

```bash
python -m venv .venv
source .venv/bin/activate            # PowerShell: .venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt
flake8 app
pytest -q
```

### 2) Docker build and run

```bash
docker build -t devops-fastapi:local .
docker compose up -d --build
```

Verify endpoints:

```bash
curl -s http://localhost:8000/
curl -s -X POST http://localhost:8000/echo -H "Content-Type: application/json" -d '{"msg":"hi","n":1}'
```

Expected:
- `GET /` returns `Hello, DevOps!`
- `POST /echo` returns `{"msg":"hi","n":1}`

Stop compose:

```bash
docker compose down
```

### Optional Make targets

```bash
make lint
make test
make docker-build
make docker-run
```

## Terraform (AWS infra)

### Prerequisites

- Terraform >= 1.6
- AWS credentials configured (`aws configure` or env vars)
- Existing EC2 key pair in target region

### Variables you must provide

- `key_name`
- `jenkins_admin_password`

Optional variables:
- `aws_region` (default `us-east-1`)
- `create_alb` (default `false`)
- `ssh_cidr`, `jenkins_ui_cidr`, `app_ingress_cidr` (defaults open)

### Apply

```bash
cd infra
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var="key_name=YOUR_KEYPAIR" -var="jenkins_admin_password=CHANGE_ME"
terraform apply -var="key_name=YOUR_KEYPAIR" -var="jenkins_admin_password=CHANGE_ME"
```

Enable ALB:

```bash
terraform apply -var="key_name=YOUR_KEYPAIR" -var="jenkins_admin_password=CHANGE_ME" -var="create_alb=true"
```

### Outputs

```bash
terraform output
```

Important outputs:
- `jenkins_public_ip`
- `app_public_ip`
- `app_endpoint`
- `jenkins_url`

### Optional remote state (S3)

- Use `infra/backend.tf.example` as template.
- Copy to `infra/backend.tf`, replace bucket/table names, then re-run `terraform init`.

## Jenkins setup

Jenkins instance is bootstrapped by Terraform user-data (`jenkins/install_jenkins.sh.tftpl`) and installs:
- Jenkins
- Docker Engine
- Python 3 + pip/venv
- Jenkins plugins from Terraform variable `jenkins_plugins`
- Seed admin user from Terraform vars `jenkins_admin_user` + `jenkins_admin_password`

After provisioning:
1. Open `http://<jenkins_public_ip>:8080`
2. Log in with configured admin user/password
3. Add Jenkins credentials:
   - `dockerhub-creds` (Username + Token)
   - `app-ssh-key` (SSH private key to App EC2)
4. Create Pipeline job pointing to this repository root and `Jenkinsfile`

## Jenkins pipeline flow

`Jenkinsfile` stages:
1. Checkout
2. Lint (`flake8`)
3. Unit Tests (`pytest`)
4. Build Docker image
5. Push image to Docker Hub (`dockerhub-creds` -> `DOCKERHUB_USER`/`DOCKERHUB_TOKEN`)
6. Deploy to App EC2 via SSH using `jenkins/deploy_app.sh`
7. Health check (`GET /` contains `Hello, DevOps!`)

Pipeline parameters:
- `DOCKERHUB_REPO` (example: `youruser/devops-fastapi`)
- `APP_HOST` (App EC2 public IP, or ALB DNS without `http://`)
- `APP_SSH_USER` (default `ubuntu`)

## Endpoint testing on deployed host

Without ALB:

```bash
curl -s http://APP_PUBLIC_IP/
curl -s -X POST http://APP_PUBLIC_IP/echo -H "Content-Type: application/json" -d '{"hello":"aws"}'
```

With ALB:

```bash
curl -s http://ALB_DNS/
curl -s -X POST http://ALB_DNS/echo -H "Content-Type: application/json" -d '{"hello":"aws"}'
```

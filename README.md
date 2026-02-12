# DevOps Assignment Portfolio Repo

Repository structure:
- `terraform/`: modular Terraform (VPC + IAM + EKS + 2 node groups + ECR)
- `terraform/bootstrap/`: S3 backend bucket + DynamoDB lock table
- `app/`: Flask app + Dockerfile
- `helm/`: Helm chart

## FREE Path (Local Validation Only)

No AWS resources are created in this path.

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
helm lint ./helm
```

Optional local app run:

```bash
docker build -t devops-assignment-app:local ./app
docker run --rm -p 8080:8080 devops-assignment-app:local
```

## AWS Path (Creates Resources, Costs Money)

Warning: this path creates billable AWS resources (EKS, EC2, NAT Gateway, LoadBalancer, ECR, S3, DynamoDB).

### 1) Bootstrap backend infra

```bash
terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap plan -out=tfplan-bootstrap
terraform -chdir=terraform/bootstrap apply tfplan-bootstrap
```

### 2) Provision main infra

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

### 3) Use outputs

```bash
terraform -chdir=terraform output eks_cluster_name
terraform -chdir=terraform output eks_cluster_endpoint
terraform -chdir=terraform output ecr_repository_url
terraform -chdir=terraform output eks_cluster_iam_role_arn
```

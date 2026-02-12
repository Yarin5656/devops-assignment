# DevOps Assignment (EKS + Terraform + Docker + Helm + GitHub Actions)

## Overview
Build an end-to-end pipeline that:
1) Provisions an AWS EKS cluster using Terraform
2) Containerizes a Flask app using Docker and pushes it to AWS ECR
3) Deploys the app to EKS using Helm and exposes it to the internet
4) Automates build+deploy using GitHub Actions

## Repo structure (must exist)
- /terraform     Terraform code for AWS infra
- /app           Flask app (app.py) + Dockerfile
- /helm          Helm chart for deployment to EKS
- /.github/workflows   GitHub Actions workflows
- README.md      Full instructions to run everything

---

## 1) Terraform – AWS Infrastructure
Write Terraform to create:

### Infrastructure
- S3 bucket to store Terraform state
- VPC with two subnets:
  - Public subnet
  - Private subnet
- EKS cluster
- Two EKS node groups (one in each subnet)
- AWS ECR repository to store container images
- IAM roles + necessary permissions

### Terraform minimum outputs
- EKS cluster name
- EKS cluster endpoint
- ECR repository URL
- IAM role ARN
- Add any other relevant outputs (subnet IDs, VPC ID, node role ARNs, etc.)

### Requirements / Best practices
- Use remote state in S3 (and locking if possible)
- Use cost-aware defaults (small node sizes, minimal counts)
- Tag resources
- Keep code organized and readable (modules are OK but not required)

---

## 2) Dockerize the provided application
In /app directory there is a Flask application (app.py).
- Create Dockerfile
- Build Docker image
- Push image to the AWS ECR repository created in step 1
- Provide README steps on how to build and push the image

---

## 3) Deploy the application using Helm
- Create a Helm chart to deploy the app to EKS
- App must be accessible from the internet after deployment
- Provide the public endpoint URL for accessing the application

---

## 4) Automate deployment using GitHub Actions
Create a GitHub Actions workflow that on push to main:
1) Builds & pushes Docker image to ECR
2) Deploys/updates the application in EKS using Helm

### Bonus
- Bonus 1: Add GitHub Actions workflow for deploying the infrastructure using Terraform
- Bonus 2: Deploy monitoring for the application (basic is fine)

---

## Notes
- Do NOT commit secrets. Use GitHub Secrets.
- Prefer AWS best practices (least privilege IAM).
- Provide step-by-step README.md to run:
  - Terraform apply
  - ECR login + docker push
  - EKS kubeconfig setup
  - Helm install/upgrade
  - How to find the public LoadBalancer URL

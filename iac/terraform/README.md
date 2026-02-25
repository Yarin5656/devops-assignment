# iac/terraform (LocalStack-only)

This folder is intentionally configured for LocalStack endpoint usage only.

## Safety
- Endpoint default: `http://localhost:4566`
- Credentials are static test values (`test/test`)
- Never point this provider at real AWS

## Example (do not run against real cloud)
```bash
terraform -chdir=iac/terraform init
terraform -chdir=iac/terraform plan
```

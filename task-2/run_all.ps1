$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if ([string]::IsNullOrWhiteSpace($env:AWS_ACCESS_KEY_ID)) { $env:AWS_ACCESS_KEY_ID = "test" }
if ([string]::IsNullOrWhiteSpace($env:AWS_SECRET_ACCESS_KEY)) { $env:AWS_SECRET_ACCESS_KEY = "test" }
if ([string]::IsNullOrWhiteSpace($env:AWS_DEFAULT_REGION)) { $env:AWS_DEFAULT_REGION = "us-east-1" }

function Wait-ContainerHealthy {
  param(
    [Parameter(Mandatory = $true)][string]$ContainerName,
    [int]$TimeoutSeconds = 180
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $status = docker inspect --format='{{.State.Health.Status}}' $ContainerName 2>$null
    if ($LASTEXITCODE -eq 0 -and $status -eq 'healthy') {
      Write-Host "$ContainerName is healthy."
      return
    }
    Start-Sleep -Seconds 2
  }

  throw "Timed out waiting for $ContainerName health status."
}

Write-Host "Starting docker services..."
docker compose up -d --build | Out-Host

Wait-ContainerHealthy -ContainerName 'task2-localstack'
Wait-ContainerHealthy -ContainerName 'task2-postgres'

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  throw "Terraform is required but not found in PATH."
}

Write-Host "Applying Terraform against LocalStack..."
terraform -chdir=infra/terraform init -input=false | Out-Host
if ($LASTEXITCODE -ne 0) { throw "terraform init failed" }

terraform -chdir=infra/terraform apply -auto-approve -input=false | Out-Host
if ($LASTEXITCODE -ne 0) { throw "terraform apply failed" }

Write-Host "Environment ready. Next verification commands:"
Write-Host "  .\verify.ps1"
Write-Host "  docker logs -f task2-worker"
Write-Host "  aws --endpoint-url=http://localhost:4566 s3 ls"
Write-Host "  aws --endpoint-url=http://localhost:4566 sqs list-queues"
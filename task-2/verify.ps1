$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

if ([string]::IsNullOrWhiteSpace($env:AWS_ACCESS_KEY_ID)) { $env:AWS_ACCESS_KEY_ID = "test" }
if ([string]::IsNullOrWhiteSpace($env:AWS_SECRET_ACCESS_KEY)) { $env:AWS_SECRET_ACCESS_KEY = "test" }
if ([string]::IsNullOrWhiteSpace($env:AWS_DEFAULT_REGION)) { $env:AWS_DEFAULT_REGION = "us-east-1" }

$bucket = "task2-ingest"
$queueName = "task2-ingest-queue"

$samplePath = Join-Path $root "data\sample.geojson"
New-Item -ItemType Directory -Force -Path (Join-Path $root "data") | Out-Null

$sample = '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"Point","coordinates":[34.7818,32.0853]},"properties":{"name":"tel-aviv","pipeline":"verify"}}]}'
$sample | Set-Content -NoNewline -Path $samplePath

Write-Host "Stopping worker briefly to verify SQS message presence..."
docker compose stop worker | Out-Host

Write-Host "Uploading sample.geojson to S3..."
aws --endpoint-url=http://localhost:4566 --region us-east-1 s3 cp $samplePath "s3://$bucket/sample.geojson" | Out-Host
if ($LASTEXITCODE -ne 0) { throw "Failed uploading sample.geojson" }

$queueUrl = (aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs get-queue-url --queue-name $queueName | ConvertFrom-Json).QueueUrl
Write-Host "Queue URL: $queueUrl"

$msgJson = $null
$foundMessage = $false
for ($i = 0; $i -lt 10; $i++) {
  $candidate = aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs receive-message --queue-url $queueUrl --max-number-of-messages 1 --wait-time-seconds 2 | ConvertFrom-Json
  if ($candidate.PSObject.Properties.Name -contains "Messages" -and $candidate.Messages.Count -gt 0) {
    $msgJson = $candidate
    $foundMessage = $true
    break
  }
}

if (-not $foundMessage) {
  throw "No SQS message received after uploading sample.geojson"
}

$body = $msgJson.Messages[0].Body | ConvertFrom-Json
$key = $body.Records[0].s3.object.key
Write-Host "Received SQS message for key: $key"

$receipt = $msgJson.Messages[0].ReceiptHandle
aws --endpoint-url=http://localhost:4566 --region us-east-1 sqs change-message-visibility --queue-url $queueUrl --receipt-handle $receipt --visibility-timeout 0 | Out-Null

Write-Host "Starting worker and waiting for PostGIS ingest..."
docker compose start worker | Out-Host

$deadline = (Get-Date).AddSeconds(90)
$ingested = $false
while ((Get-Date) -lt $deadline) {
  $count = docker exec task2-postgres psql -U geo -d geodb -t -A -c "SELECT COUNT(*) FROM geo_features WHERE source_key='sample.geojson';"
  if ($LASTEXITCODE -eq 0 -and [int]$count -gt 0) {
    $ingested = $true
    Write-Host "PostGIS rows found for sample.geojson: $count"
    break
  }
  Start-Sleep -Seconds 3
}

if (-not $ingested) {
  throw "GeoJSON row was not inserted into PostGIS within timeout"
}

Write-Host "Verification passed: S3 upload -> SQS message -> PostGIS rows."

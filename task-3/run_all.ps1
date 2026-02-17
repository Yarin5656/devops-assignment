$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
  param([string]$Message)
  if ($LASTEXITCODE -ne 0) {
    throw $Message
  }
}

Write-Host "[0/5] Checking Docker Desktop engine..."
docker info > $null
Assert-LastExitCode "Docker engine is not reachable"

Write-Host "[1/5] Building and starting containers..."
docker compose up -d --build
Assert-LastExitCode "docker compose up failed"

Write-Host "[2/5] Waiting for cluster daemons on webz-001..003..."
$nodes = @("webz-001", "webz-002", "webz-003")
foreach ($n in $nodes) {
  $ok = $false
  for ($i = 0; $i -lt 60; $i++) {
    docker exec $n bash -lc "pgrep -x corosync >/dev/null && pgrep -x pacemakerd >/dev/null"
    if ($LASTEXITCODE -eq 0) {
      $ok = $true
      break
    }
    Start-Sleep -Seconds 2
  }
  if (-not $ok) {
    throw "Cluster daemons not ready on $n"
  }
}

Write-Host "[3/5] Bootstrapping Pacemaker resources..."
docker exec webz-001 bash -lc "/opt/bootstrap/bootstrap_cluster.sh"
Assert-LastExitCode "Cluster bootstrap failed"

Write-Host "[4/5] Waiting for floating IP to respond..."
$vipReady = $false
for ($i = 0; $i -lt 40; $i++) {
  docker exec webz-004 bash -lc "curl -fsS http://172.28.0.100:80 >/dev/null"
  if ($LASTEXITCODE -eq 0) {
    $vipReady = $true
    break
  }
  Start-Sleep -Seconds 3
}
if (-not $vipReady) {
  throw "Floating IP is not reachable from Jenkins node"
}

Write-Host "[5/5] Basic health summary"
Write-Host "Cluster status:"
docker exec webz-001 bash -lc "crm_mon -1"
Assert-LastExitCode "Unable to query cluster status"

Write-Host "HTTP check:"
docker exec webz-004 bash -lc "curl -i -s http://172.28.0.100:80 | head -n 8"
Assert-LastExitCode "Unable to query VIP"

Write-Host "Done. Jenkins UI: http://localhost:8080  | Job: ha-monitor"
Write-Host ""
Write-Host "Verification commands:"
Write-Host '1) Active node: docker exec webz-001 bash -lc "crm_mon -1"'
Write-Host '2) VIP owner IPs: docker exec webz-001 bash -lc "ip -4 addr show eth0"'
Write-Host '3) Failover test: docker stop webz-001'
Write-Host '4) Post-failover status: docker exec webz-002 bash -lc "crm_mon -1"'
Write-Host '5) HTTP + active header: docker exec webz-004 bash -lc "curl -i -s http://172.28.0.100:80 | head -n 12"'
Write-Host '6) Jenkins builds: docker exec webz-004 bash -lc "ls -la /var/jenkins_home/jobs/ha-monitor/builds"'
Write-Host '7) Persisted logs: Get-Content .\logs\ha_monitor.log -Tail 20'

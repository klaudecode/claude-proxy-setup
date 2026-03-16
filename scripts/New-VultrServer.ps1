#Requires -Version 5.1
# Create a new Vultr VPS in New York (EWR). Requires VULTR_API_KEY in .env.
# Usage: .\New-VultrServer.ps1 [-RepoRoot "C:\path\to\folder"]
# Then set SSH_HOST in .env to the new IP and run Setup-Server.ps1.

param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = "Stop"
$envPath = Join-Path $RepoRoot ".env"
if (-not (Test-Path $envPath)) { throw "No .env at $envPath. Add VULTR_API_KEY and run again." }

Get-Content $envPath | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)=(.*)$') {
    $k = $Matches[1].Trim()
    $v = $Matches[2].Trim().Trim('"').Trim("'")
    [Environment]::SetEnvironmentVariable($k, $v, "Process")
  }
}

$apiKey = [Environment]::GetEnvironmentVariable("VULTR_API_KEY", "Process")
if (-not $apiKey) { throw "VULTR_API_KEY not set in .env. Get it from: https://my.vultr.com/settings/#settingsapi" }

$region = [Environment]::GetEnvironmentVariable("VULTR_REGION", "Process")
if (-not $region) { $region = "ewr" }  # Newark / New York area

$plan = [Environment]::GetEnvironmentVariable("VULTR_PLAN", "Process")
if (-not $plan) { $plan = "vc2-1c-1gb" }  # Small instance

# Ubuntu 22.04 LTS
$osId = 1743

$body = @{
  region   = $region
  plan     = $plan
  os_id    = $osId
  label    = "claude-proxy-ny"
  hostname = "claude-proxy"
} | ConvertTo-Json

$headers = @{
  "Authorization" = "Bearer $apiKey"
  "Content-Type"  = "application/json"
}

Write-Host "Creating VPS in $region (New York area), plan $plan..."
try {
  $r = Invoke-RestMethod -Uri "https://api.vultr.com/v2/instances" -Method Post -Headers $headers -Body $body
} catch {
  Write-Error "Vultr API error: $_"
  exit 1
}

$id = $r.instance.id
Write-Host "Instance ID: $id. Waiting for IP (up to 3 min)..."

$maxWait = 60
$interval = 5
$elapsed = 0
$mainIp = $null

while ($elapsed -lt $maxWait) {
  Start-Sleep -Seconds $interval
  $elapsed += $interval
  $inst = Invoke-RestMethod -Uri "https://api.vultr.com/v2/instances/$id" -Method Get -Headers @{ "Authorization" = "Bearer $apiKey" }
  $mainIp = $inst.instance.main_ip
  if ($mainIp) {
    Write-Host ""
    Write-Host "Server is up. New York (EWR) VPS IP: $mainIp"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. In .env set: SSH_HOST=$mainIp"
    Write-Host "  2. In Vultr dashboard, add your SSH key to this server (or use the root password from the server's Overview)."
    Write-Host "  3. Run: .\scripts\Setup-Server.ps1 -RepoRoot `"$RepoRoot`""
    exit 0
  }
  Write-Host "  ... waiting ($elapsed s)"
}

Write-Host "Timeout. Check Vultr dashboard for instance $id and use its IP as SSH_HOST."

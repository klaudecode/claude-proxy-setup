#Requires -Version 5.1
# One script to get claude-wg-client.conf and xray-client.json into out\.
# Tries export first (fast). If missing on server, runs full setup (install + download).
# Usage: .\Get-ClientConfigs.ps1 [-RepoRoot "C:\Users\Kyle\Documents\claude-proxy-setup"]

param([string]$RepoRoot = "C:\Users\Kyle\Documents\claude-proxy-setup")

$ErrorActionPreference = "Stop"
$OutDir = Join-Path $RepoRoot "out"
$wgConf = Join-Path $OutDir "claude-wg-client.conf"
$xrayJson = Join-Path $OutDir "xray-client.json"
$scriptsDir = Split-Path $PSScriptRoot -Parent
$scriptDir = $PSScriptRoot

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Test-ConfigsExist {
  (Test-Path $wgConf) -and (Test-Path $xrayJson)
}

# 1) Try quick export (server already has configs)
Write-Host "Trying to pull configs from server..."
$exportScript = Join-Path $scriptDir "Export-ClientConfigs.ps1"
try {
  & $exportScript -RepoRoot $RepoRoot 2>&1 | Out-Null
  if (Test-ConfigsExist) {
    Write-Host "Done. Configs in: $OutDir"
    Write-Host "  - claude-wg-client.conf"
    Write-Host "  - xray-client.json"
    exit 0
  }
} catch {
  Write-Host "Export failed (server may not have configs yet). Running full setup..."
}

# 2) Full setup (install on server + download)
Write-Host "Running full setup (SSH + install + download). This may take a few minutes..."
$setupScript = Join-Path $scriptDir "Setup-Server.ps1"
& $setupScript -RepoRoot $RepoRoot

if (Test-ConfigsExist) {
  Write-Host ""
  Write-Host "Configs ready: $OutDir"
  Write-Host "  - claude-wg-client.conf  -> import in WireGuard"
  Write-Host "  - xray-client.json       -> import in v2rayN"
} else {
  Write-Host "Setup finished but configs not found. Check .env (SSH_HOST, SSH_USER, key/password) and server access."
  exit 1
}

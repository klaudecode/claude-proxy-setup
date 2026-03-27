#Requires -Version 5.1
# Download standalone Xray core (no GUI needed). Runs as a simple background process.
# Usage: .\Install-XrayCore.ps1 [-RepoRoot "C:\path\to\folder"]

param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = "Stop"
$xrayDir = Join-Path $RepoRoot "xray"
$xrayExe = Join-Path $xrayDir "xray.exe"

if (Test-Path $xrayExe) {
  Write-Host "Xray core already installed at: $xrayExe"
  return
}

$zipPath = Join-Path $env:TEMP "xray-core-$([Guid]::NewGuid().ToString('N').Substring(0,8)).zip"

Write-Host "Finding latest Xray core release..."
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/XTLS/Xray-core/releases/latest" -Headers @{ "Accept" = "application/vnd.github.v3+json" }
$asset = $releases.assets | Where-Object { $_.name -match "Xray-windows-64" -and $_.name -match "\.zip$" } | Select-Object -First 1

if (-not $asset) {
  throw "Could not find Xray Windows 64-bit asset. Download manually from: https://github.com/XTLS/Xray-core/releases"
}

Write-Host "Downloading: $($asset.name) ..."
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

Write-Host "Extracting to: $xrayDir"
New-Item -ItemType Directory -Force -Path $xrayDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $xrayDir -Force
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

if (Test-Path $xrayExe) {
  Write-Host "Xray core installed at: $xrayExe"
} else {
  $found = Get-ChildItem -Path $xrayDir -Recurse -Filter "xray.exe" | Select-Object -First 1
  if ($found) {
    Write-Host "Xray core installed at: $($found.FullName)"
  } else {
    throw "xray.exe not found after extraction. Check $xrayDir manually."
  }
}

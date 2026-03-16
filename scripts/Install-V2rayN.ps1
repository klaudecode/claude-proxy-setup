#Requires -Version 5.1
# Download and extract v2rayN (with Xray core) for Windows. Then import out\xray-client.json in the app.
# Usage: .\Install-V2rayN.ps1 [-RepoRoot "C:\path\to\folder"]

param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = "Stop"
$v2rayNDir = Join-Path $RepoRoot "v2rayN"
$zipPath = Join-Path $env:TEMP "v2rayN-with-core-$([Guid]::NewGuid().ToString('N').Substring(0,8)).zip"

# Find latest v2rayN release with "With-Core" or "Core" in asset name (Windows 64)
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/2dust/v2rayN/releases" -Headers @{ "Accept" = "application/vnd.github.v3+json" }
$asset = $releases[0].assets | Where-Object {
  $_.name -match "windows.*64" -and ($_.name -match "With-Core|With_Core|SelfContained")
} | Select-Object -First 1
if (-not $asset) {
  $asset = $releases[0].assets | Where-Object { $_.name -match "windows.*64" } | Select-Object -First 1
}
if (-not $asset) {
  Write-Error "Could not find v2rayN Windows 64 asset. Download manually from: https://github.com/2dust/v2rayN/releases"
  exit 1
}

$downloadUrl = $asset.browser_download_url
Write-Host "Downloading v2rayN: $($asset.name)..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing

Write-Host "Extracting to: $v2rayNDir"
New-Item -ItemType Directory -Force -Path $v2rayNDir | Out-Null
Expand-Archive -Path $zipPath -DestinationPath $v2rayNDir -Force
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

$exe = Get-ChildItem -Path $v2rayNDir -Recurse -Filter "v2rayN.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe) {
  Write-Host "Opening v2rayN..."
  Start-Process -FilePath $exe.FullName
  Write-Host ""
  Write-Host "Next: In v2rayN, set core to Xray (Settings), then:"
  Write-Host "  Servers -> Import from config file -> choose: $RepoRoot\out\xray-client.json"
  Write-Host "  Start the core (do NOT enable System proxy). Use port 1080 for Claude."
} else {
  Write-Host "Extracted to $v2rayNDir. Run v2rayN.exe from there, then import $RepoRoot\out\xray-client.json"
}

#Requires -Version 5.1
# Master orchestrator: runs all setup steps in order.
# 1. Validates credentials in .env
# 2. Installs Xray core locally (if needed)
# 3. Runs server setup (WireGuard + Xray on Vultr) if needed
# 4. Generates a unique WireGuard key pair for THIS machine
# 5. Adds this machine as a new peer on the server
# 6. Creates client config and imports WireGuard tunnel
# 7. Configures Cursor and Claude Code proxy settings
#
# Usage: .\Full-Setup.ps1 [-RepoRoot "C:\path\to\folder"]

param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = "Stop"
$ScriptsDir = $PSScriptRoot
$OutDir = Join-Path $RepoRoot "out"
$envPath = Join-Path $RepoRoot ".env"

function Write-Step($n, $msg) { Write-Host "`n=== Step $n : $msg ===" -ForegroundColor Cyan }
function Write-Ok($msg)       { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg)     { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg)     { Write-Host "  [FAIL] $msg" -ForegroundColor Red }

# ── Step 1: Validate .env ──
Write-Step 1 "Checking credentials"

if (-not (Test-Path $envPath)) {
  Write-Fail ".env file not found at $envPath"
  Write-Host "  Copy .env.example to .env and fill in your credentials, then re-run."
  exit 1
}

$creds = @{}
Get-Content $envPath | ForEach-Object {
  if ($_ -match '^\s*([^#=]+)=(.*)$') {
    $k = $Matches[1].Trim()
    $v = $Matches[2].Trim().Trim('"').Trim("'")
    $creds[$k] = $v
  }
}

$required = @("SSH_HOST", "BRIGHT_DATA_HOST", "BRIGHT_DATA_PORT", "BRIGHT_DATA_USER", "BRIGHT_DATA_PASS")
$missing = $required | Where-Object { -not $creds[$_] -or $creds[$_] -match "your-|xxx" }
if ($missing) {
  Write-Fail "Missing or placeholder values in .env: $($missing -join ', ')"
  exit 1
}

$sshHost   = $creds["SSH_HOST"]
$sshUser   = if ($creds["SSH_USER"]) { $creds["SSH_USER"] } else { "root" }
$sshKeyPath = $creds["SSH_KEY_PATH"]
$wgPort    = if ($creds["WIREGUARD_PORT"]) { $creds["WIREGUARD_PORT"] } else { "51820" }

if (-not $sshKeyPath -or -not (Test-Path $sshKeyPath)) {
  $defaultKey = "$env:USERPROFILE\.ssh\id_ed25519"
  if (Test-Path $defaultKey) {
    $sshKeyPath = $defaultKey
    Write-Warn "SSH_KEY_PATH not set, using default: $defaultKey"
  } else {
    Write-Fail "No SSH key found. Set SSH_KEY_PATH in .env or run: ssh-keygen -t ed25519"
    exit 1
  }
}

$sshArgs = @("-o", "StrictHostKeyChecking=accept-new", "-o", "BatchMode=yes", "-i", $sshKeyPath)
$target = "${sshUser}@${sshHost}"

Write-Ok "Credentials valid (SSH_HOST=$sshHost)"

# ── Step 2: Install Xray core locally ──
Write-Step 2 "Installing Xray core (local)"

$xrayExe = Join-Path $RepoRoot "xray\xray.exe"
if (Test-Path $xrayExe) {
  Write-Ok "Xray core already installed"
} else {
  & "$ScriptsDir\Install-XrayCore.ps1" -RepoRoot $RepoRoot
  if (-not (Test-Path $xrayExe)) {
    $found = Get-ChildItem -Path (Join-Path $RepoRoot "xray") -Recurse -Filter "xray.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { $xrayExe = $found.FullName }
    else { Write-Fail "Xray core install failed"; exit 1 }
  }
  Write-Ok "Xray core installed"
}

# ── Step 3: Check if server has WireGuard + Xray already ──
Write-Step 3 "Checking server setup"

$serverReady = & ssh @sshArgs $target "command -v wg >/dev/null && command -v xray >/dev/null && echo READY || echo MISSING" 2>&1
if ($serverReady -match "READY") {
  Write-Ok "Server already has WireGuard + Xray installed"
} else {
  Write-Host "  Running server setup..."
  & "$ScriptsDir\Setup-Server.ps1" -RepoRoot $RepoRoot
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Fail "Server setup failed"
    exit 1
  }
  Write-Ok "Server setup complete"
}

# ── Step 4: Generate unique WireGuard key pair for this machine ──
Write-Step 4 "Generating WireGuard keys for this machine"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$wgExe = "C:\Program Files\WireGuard\wg.exe"
if (-not (Test-Path $wgExe)) {
  Write-Fail "WireGuard not installed. Get it from: https://www.wireguard.com/install/"
  exit 1
}

$privKey = & $wgExe genkey
$pubKey = echo $privKey | & $wgExe pubkey
Write-Ok "Keys generated (pubkey: $($pubKey.Substring(0,20))...)"

# ── Step 5: Add this machine as a peer on the server ──
Write-Step 5 "Adding this machine as a peer on the server"

$peerInfo = & ssh @sshArgs $target "wg show wg0 allowed-ips 2>/dev/null" 2>&1
$usedIps = @()
foreach ($line in $peerInfo -split "`n") {
  if ($line -match "10\.66\.66\.(\d+)/32") { $usedIps += [int]$Matches[1] }
}
$nextOctet = 2
while ($usedIps -contains $nextOctet) { $nextOctet++ }
$clientIp = "10.66.66.$nextOctet"

Write-Host "  Assigning IP: $clientIp"

& ssh @sshArgs $target "wg set wg0 peer $pubKey allowed-ips ${clientIp}/32; wg-quick save wg0 2>/dev/null" 2>&1 | Out-Null

$serverPubKey = & ssh @sshArgs $target "wg show wg0 public-key" 2>&1
$serverPubKey = $serverPubKey.Trim()

Write-Ok "Peer added on server ($clientIp)"

# ── Step 6: Create client config and import tunnel ──
Write-Step 6 "Creating WireGuard client config"

$clientConf = @"
[Interface]
PrivateKey = $privKey
Address = ${clientIp}/24
MTU = 1280

[Peer]
PublicKey = $serverPubKey
Endpoint = ${sshHost}:${wgPort}
AllowedIPs = 10.66.66.0/24
PersistentKeepalive = 25
"@

$confPath = Join-Path $OutDir "claude-wg-client.conf"
[System.IO.File]::WriteAllText($confPath, $clientConf, (New-Object System.Text.UTF8Encoding $false))
Write-Ok "Config written to $confPath"

# Create Xray client config
$xrayClientConf = @"
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "tag": "socks-in",
      "listen": "127.0.0.1",
      "port": 1080,
      "protocol": "socks",
      "settings": { "auth": "noauth", "udp": true }
    },
    {
      "tag": "http-in",
      "listen": "127.0.0.1",
      "port": 1081,
      "protocol": "http",
      "settings": {}
    }
  ],
  "outbounds": [{
    "tag": "proxy",
    "protocol": "socks",
    "settings": {
      "servers": [{
        "address": "10.66.66.1",
        "port": 1080
      }]
    }
  }]
}
"@

$xrayConfPath = Join-Path $OutDir "xray-client.json"
[System.IO.File]::WriteAllText($xrayConfPath, $xrayClientConf, (New-Object System.Text.UTF8Encoding $false))
Write-Ok "Xray client config written"

# Import WireGuard tunnel
Write-Host "  Importing WireGuard tunnel (may need admin approval)..."
$existingSvc = Get-Service -Name "WireGuardTunnel`$claude-wg-client" -ErrorAction SilentlyContinue
if ($existingSvc) {
  Start-Process -FilePath "C:\Program Files\WireGuard\wireguard.exe" -ArgumentList "/uninstalltunnelservice claude-wg-client" -Verb RunAs -Wait
  Start-Sleep 3
}
Start-Process -FilePath "C:\Program Files\WireGuard\wireguard.exe" -ArgumentList "/installtunnelservice `"$confPath`"" -Verb RunAs -Wait
Start-Sleep 4

$svc = Get-Service -Name "WireGuardTunnel`$claude-wg-client" -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
  Write-Ok "WireGuard tunnel activated"
} else {
  Write-Warn "WireGuard tunnel may need manual activation in the WireGuard GUI"
}

# ── Step 7: Configure Cursor and Claude Code ──
Write-Step 7 "Configuring app proxy settings"

$cursorSettingsPath = "$env:APPDATA\Cursor\User\settings.json"
if (Test-Path $cursorSettingsPath) {
  $settings = Get-Content $cursorSettingsPath -Raw | ConvertFrom-Json
  $settings | Add-Member -NotePropertyName "http.proxy" -NotePropertyValue "socks5://127.0.0.1:1080" -Force
  $settings | Add-Member -NotePropertyName "http.proxyStrictSSL" -NotePropertyValue $false -Force
  $settings | ConvertTo-Json -Depth 10 | Set-Content $cursorSettingsPath -Encoding UTF8
  Write-Ok "Cursor proxy set to socks5://127.0.0.1:1080"
} else {
  Write-Warn "Cursor settings.json not found — set proxy manually in Cursor settings"
}

$claudeCodeSettings = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $claudeCodeSettings) {
  $cs = Get-Content $claudeCodeSettings -Raw | ConvertFrom-Json
  if (-not $cs.env) { $cs | Add-Member -NotePropertyName "env" -NotePropertyValue @{} -Force }
  $cs.env | Add-Member -NotePropertyName "HTTPS_PROXY" -NotePropertyValue "socks5://127.0.0.1:1080" -Force
  $cs.env | Add-Member -NotePropertyName "HTTP_PROXY" -NotePropertyValue "socks5://127.0.0.1:1080" -Force
  $cs.env | Add-Member -NotePropertyName "NO_PROXY" -NotePropertyValue "localhost,127.0.0.1" -Force
  $cs | ConvertTo-Json -Depth 10 | Set-Content $claudeCodeSettings -Encoding UTF8
  Write-Ok "Claude Code proxy configured"
}

# ── Done ──
Write-Step 8 "Setup complete!"

Write-Host ""
Write-Host "  Traffic path:" -ForegroundColor White
Write-Host "    Claude/Cursor -> socks5://127.0.0.1:1080"
Write-Host "                  -> WireGuard -> Vultr VPS"
Write-Host "                  -> Xray -> BrightData -> Internet"
Write-Host ""
Write-Host "  This machine's WireGuard IP: $clientIp" -ForegroundColor White
Write-Host ""
Write-Host "  Daily startup:" -ForegroundColor White
Write-Host "    1. Double-click Start-Proxy.bat"
Write-Host "    2. Double-click launch-claude-with-proxy.bat"
Write-Host "    3. Open Cursor normally"
Write-Host ""

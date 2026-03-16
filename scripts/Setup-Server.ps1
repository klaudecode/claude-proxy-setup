#Requires -Version 5.1
# One-shot setup: reads .env, builds a single remote script with all configs embedded,
# runs it over ONE ssh session, then ONE scp to pull client configs back.
# No ControlMaster needed. Password is entered at most twice (once for ssh, once for scp).
# Usage: .\Setup-Server.ps1 [-RepoRoot "C:\Users\Kyle\Documents\claude-proxy-setup"]

param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))

$ErrorActionPreference = "Stop"
$ScriptsDir = $PSScriptRoot
$TemplatesDir = Join-Path (Split-Path $PSScriptRoot -Parent) "templates"
$OutDir = Join-Path $RepoRoot "out"

function Load-Creds {
  $envPath = Join-Path $RepoRoot ".env"
  $jsonPath = Join-Path $RepoRoot "secrets.json"
  if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
      if ($_ -match '^\s*([^#=]+)=(.*)$') {
        $k = $Matches[1].Trim()
        $v = $Matches[2].Trim().Trim('"').Trim("'")
        [Environment]::SetEnvironmentVariable($k, $v, "Process")
      }
    }
    return
  }
  if (Test-Path $jsonPath) {
    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
    @("SSH_HOST","SSH_USER","SSH_KEY_PATH","SSH_PASSWORD","BRIGHT_DATA_HOST","BRIGHT_DATA_PORT","BRIGHT_DATA_USER","BRIGHT_DATA_PASS","WIREGUARD_PORT","XRAY_PORT","WG_CLIENT_IP","WG_SERVER_IP") | ForEach-Object {
      $p = $j.PSObject.Properties[$_]
      if ($p) { [Environment]::SetEnvironmentVariable($_, $p.Value, "Process") }
    }
    return
  }
  throw "No .env or secrets.json found in $RepoRoot"
}

function Get-Env($name, $default = "") {
  $v = [Environment]::GetEnvironmentVariable($name, "Process")
  if ($v) { return $v } else { return $default }
}

Load-Creds

$sshHost     = Get-Env "SSH_HOST"
$sshUser     = Get-Env "SSH_USER" "root"
$sshKeyPath  = Get-Env "SSH_KEY_PATH"
$bdHost      = Get-Env "BRIGHT_DATA_HOST"
$bdPort      = Get-Env "BRIGHT_DATA_PORT" "22225"
$bdUser      = Get-Env "BRIGHT_DATA_USER"
$bdPass      = Get-Env "BRIGHT_DATA_PASS"
$wgPort      = Get-Env "WIREGUARD_PORT" "51820"
$xrayPort    = Get-Env "XRAY_PORT" "1080"
$wgClientIp  = Get-Env "WG_CLIENT_IP" "10.66.66.2"
$wgServerIp  = Get-Env "WG_SERVER_IP" "10.66.66.1"

if (-not $sshHost) { throw "SSH_HOST not set in .env" }

$target = "${sshUser}@${sshHost}"
$sshArgs = @("-o", "StrictHostKeyChecking=accept-new")
if ($sshKeyPath -and (Test-Path $sshKeyPath)) { $sshArgs += @("-i", $sshKeyPath) }

$wg0Tpl = (Get-Content (Join-Path $TemplatesDir "wg0.conf.tpl") -Raw)
$wgClientTpl = (Get-Content (Join-Path $TemplatesDir "wg-client.conf.tpl") -Raw)
$xrayServerTpl = (Get-Content (Join-Path $TemplatesDir "xray-server.json.tpl") -Raw)
$xrayClientTpl = (Get-Content (Join-Path $TemplatesDir "xray-client.json.tpl") -Raw)

$remoteScript = @"
#!/bin/bash
set -euo pipefail
SUDO=""
[ "`$(id -u)" -eq 0 ] || SUDO="sudo"

WG_PORT=$wgPort
XRAY_PORT=$xrayPort
WG_SERVER_IP=$wgServerIp
WG_CLIENT_IP=$wgClientIp
BD_HOST=$bdHost
BD_PORT=$bdPort
BD_USER=$bdUser
BD_PASS=$bdPass
SSH_HOST=$sshHost
OUT_DIR=/opt/claude-proxy/out

`$SUDO mkdir -p /opt/claude-proxy/out

# Install WireGuard
if ! command -v wg &>/dev/null; then
  `$SUDO apt-get update -qq && `$SUDO apt-get install -y -qq wireguard
fi

# Generate WireGuard keys and configs if not already done
WG_CONF=/etc/wireguard/wg0.conf
if [ ! -f "`$WG_CONF" ]; then
  WG_SERVER_PRIVATE=`$(wg genkey)
  WG_SERVER_PUBLIC=`$(echo "`$WG_SERVER_PRIVATE" | wg pubkey)
  WG_CLIENT_PRIVATE=`$(wg genkey)
  WG_CLIENT_PUBLIC=`$(echo "`$WG_CLIENT_PRIVATE" | wg pubkey)

  MAIN_IF=`$(ip route show default | awk '{print `$5}' | head -1)
  [ -z "`$MAIN_IF" ] && MAIN_IF=eth0

  cat > /tmp/wg0.conf << 'WGEOF'
$wg0Tpl
WGEOF
  sed -i "s|__WG_SERVER_PRIVATE_KEY__|`$WG_SERVER_PRIVATE|g" /tmp/wg0.conf
  sed -i "s|__WG_CLIENT_PUBLIC_KEY__|`$WG_CLIENT_PUBLIC|g" /tmp/wg0.conf
  sed -i "s|__WG_SERVER_IP__|`$WG_SERVER_IP|g" /tmp/wg0.conf
  sed -i "s|__WG_CLIENT_IP__|`$WG_CLIENT_IP|g" /tmp/wg0.conf
  sed -i "s|__WIREGUARD_PORT__|`$WG_PORT|g" /tmp/wg0.conf
  sed -i "s|eth0|`$MAIN_IF|g" /tmp/wg0.conf
  `$SUDO cp /tmp/wg0.conf `$WG_CONF
  `$SUDO chmod 600 `$WG_CONF

  # Claude-only tunnel (VPN subnet only)
  cat > `$OUT_DIR/claude-wg-client.conf << 'WGCEOF'
$wgClientTpl
WGCEOF
  sed -i "s|__WG_SERVER_PUBLIC_KEY__|`$WG_SERVER_PUBLIC|g" `$OUT_DIR/claude-wg-client.conf
  sed -i "s|__WG_CLIENT_PRIVATE_KEY__|`$WG_CLIENT_PRIVATE|g" `$OUT_DIR/claude-wg-client.conf
  sed -i "s|__WG_CLIENT_IP__|`$WG_CLIENT_IP|g" `$OUT_DIR/claude-wg-client.conf
  sed -i "s|__WIREGUARD_PORT__|`$WG_PORT|g" `$OUT_DIR/claude-wg-client.conf
  sed -i "s|__SSH_HOST__|`$SSH_HOST|g" `$OUT_DIR/claude-wg-client.conf
  sed -i "s|__WG_ALLOWED_IPS__|10.66.66.0/24|g" `$OUT_DIR/claude-wg-client.conf
  `$SUDO chmod 600 `$OUT_DIR/claude-wg-client.conf

  # Full tunnel (ALL traffic through VPN — browser + Claude same IP)
  cp `$OUT_DIR/claude-wg-client.conf `$OUT_DIR/claude-wg-full.conf
  sed -i "s|AllowedIPs = 10.66.66.0/24|AllowedIPs = 0.0.0.0/0, ::/0|g" `$OUT_DIR/claude-wg-full.conf
  `$SUDO chmod 600 `$OUT_DIR/claude-wg-full.conf

  echo "WireGuard keys generated (2 client configs: claude-only + full tunnel)."
else
  echo "WireGuard already configured."
fi

# Install Xray
if ! command -v xray &>/dev/null; then
  bash -c "`$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" || true
fi

# Xray server config
`$SUDO mkdir -p /usr/local/etc/xray
cat > /tmp/xray-server.json << 'XSEOF'
$xrayServerTpl
XSEOF
sed -i "s|__WG_SERVER_IP__|`$WG_SERVER_IP|g" /tmp/xray-server.json
sed -i "s|__XRAY_PORT__|`$XRAY_PORT|g" /tmp/xray-server.json
sed -i "s|__BRIGHT_DATA_HOST__|`$BD_HOST|g" /tmp/xray-server.json
sed -i "s|__BRIGHT_DATA_PORT__|`$BD_PORT|g" /tmp/xray-server.json
sed -i "s|__BRIGHT_DATA_USER__|`$BD_USER|g" /tmp/xray-server.json
sed -i "s|__BRIGHT_DATA_PASS__|`$BD_PASS|g" /tmp/xray-server.json
`$SUDO cp /tmp/xray-server.json /usr/local/etc/xray/config.json
`$SUDO systemctl enable xray 2>/dev/null || true
`$SUDO systemctl restart xray 2>/dev/null || true

# Xray client config (for desktop)
cat > `$OUT_DIR/xray-client.json << 'XCEOF'
$xrayClientTpl
XCEOF
sed -i "s|__XRAY_SERVER_ADDRESS__|`$WG_SERVER_IP|g" `$OUT_DIR/xray-client.json
sed -i "s|__XRAY_PORT__|`$XRAY_PORT|g" `$OUT_DIR/xray-client.json

# Firewall
if command -v ufw &>/dev/null; then
  `$SUDO ufw allow `$WG_PORT/udp 2>/dev/null || true
  `$SUDO ufw --force enable 2>/dev/null || true
fi

# Start WireGuard
`$SUDO systemctl enable wg-quick@wg0 2>/dev/null || true
`$SUDO systemctl restart wg-quick@wg0 2>/dev/null || true

echo "SETUP_COMPLETE"
echo "Client configs at `$OUT_DIR"
"@

$tmpScript = Join-Path $env:TEMP "claude-proxy-remote-setup.sh"
$remoteScript = $remoteScript -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($tmpScript, $remoteScript, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "=== Claude Proxy Setup ==="
Write-Host "Server: $target"
Write-Host ""
Write-Host "Step 1/2: SSH to server, install WireGuard + Xray, generate configs."
Write-Host "          You will be asked for the root password (from Vultr dashboard)."
Write-Host ""

Get-Content $tmpScript -Raw | & ssh @sshArgs $target "bash -s"
if ($LASTEXITCODE -ne 0) { throw "SSH setup failed. Check password and server." }

Write-Host ""
Write-Host "Step 2/2: Downloading client configs (enter password again if prompted)..."
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
& scp @sshArgs "${target}:/opt/claude-proxy/out/claude-wg-client.conf" (Join-Path $OutDir "claude-wg-client.conf")
& scp @sshArgs "${target}:/opt/claude-proxy/out/claude-wg-full.conf" (Join-Path $OutDir "claude-wg-full.conf")
& scp @sshArgs "${target}:/opt/claude-proxy/out/xray-client.json" (Join-Path $OutDir "xray-client.json")

Remove-Item $tmpScript -Force -ErrorAction SilentlyContinue

$wgOk = Test-Path (Join-Path $OutDir "claude-wg-client.conf")
$fullOk = Test-Path (Join-Path $OutDir "claude-wg-full.conf")
$xrayOk = Test-Path (Join-Path $OutDir "xray-client.json")
if ($wgOk -and $xrayOk) {
  Write-Host ""
  Write-Host "Done! Client configs saved to: $OutDir"
  Write-Host ""
  Write-Host "  TWO WireGuard configs:"
  Write-Host "  - claude-wg-full.conf    -> ALL traffic through VPN (browser + Claude = same IP)"
  Write-Host "  - claude-wg-client.conf  -> Claude-only (only VPN subnet, browser uses normal IP)"
  Write-Host ""
  Write-Host "  - xray-client.json       -> import into v2rayN; SOCKS5 at 127.0.0.1:1080"
  Write-Host ""
  Write-Host "Daily workflow:"
  Write-Host "  1. Login:  Use claude-wg-full.conf  (browser + Claude share same IP)"
  Write-Host "  2. After:  Switch to claude-wg-client.conf (only Claude uses proxy)"
  Write-Host ""
  Write-Host "Set Claude proxy to: socks5://127.0.0.1:1080"
} else {
  Write-Host "Warning: one or both config files missing. Check server output above."
}

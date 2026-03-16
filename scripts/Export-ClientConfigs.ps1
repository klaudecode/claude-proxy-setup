# Re-export client configs from server to ./out. Run from repo root.
# Optional: -RepoRoot "C:\path" to use .env and out from that folder.
param([string]$RepoRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = "Stop"
$OutDir = Join-Path $RepoRoot "out"

function Load-Creds {
  $envPath = Join-Path $RepoRoot ".env"
  $jsonPath = Join-Path $RepoRoot "secrets.json"
  if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
      if ($_ -match '^\s*([^#=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim().Trim('"').Trim("'"), "Process")
      }
    }
    return $true
  }
  if (Test-Path $jsonPath) {
    $j = Get-Content $jsonPath -Raw | ConvertFrom-Json
    @("SSH_HOST","SSH_USER","SSH_KEY_PATH") | ForEach-Object {
      $p = $j.PSObject.Properties[$_]
      if ($p) { [Environment]::SetEnvironmentVariable($_, $p.Value, "Process") }
    }
    return $true
  }
  throw "Create .env or secrets.json with SSH_HOST and SSH_USER."
}

function Get-SshTarget {
  $user = [Environment]::GetEnvironmentVariable("SSH_USER", "Process")
  $h = [Environment]::GetEnvironmentVariable("SSH_HOST", "Process")
  if (-not $user -or -not $h) { throw "SSH_USER and SSH_HOST must be set." }
  return "${user}@${h}"
}

function Invoke-ScpFrom($RemotePath, $LocalPath) {
  $key = [Environment]::GetEnvironmentVariable("SSH_KEY_PATH", "Process")
  $target = Get-SshTarget
  $scpArgs = @("${target}:${RemotePath}", $LocalPath)
  if ($key -and (Test-Path $key)) { scp -i $key -o StrictHostKeyChecking=accept-new @scpArgs }
  else { scp -o StrictHostKeyChecking=accept-new @scpArgs }
}

Load-Creds | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Invoke-ScpFrom "/opt/claude-proxy/out/claude-wg-client.conf" (Join-Path $OutDir "claude-wg-client.conf")
Invoke-ScpFrom "/opt/claude-proxy/out/xray-client.json" (Join-Path $OutDir "xray-client.json")
Write-Host "Exported to $OutDir"

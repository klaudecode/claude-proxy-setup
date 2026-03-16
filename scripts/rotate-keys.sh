#!/usr/bin/env bash
# Regenerate WireGuard and Xray client keys on the server and re-export client configs.
# Run from repo root after initial setup. Pulls new configs to ./out (re-import on desktop).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_BASE="/tmp/claude-proxy"

if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env"
  set +a
elif [[ -f "$REPO_ROOT/secrets.json" ]] && command -v jq &>/dev/null; then
  export SSH_HOST=$(jq -r '.SSH_HOST // empty' "$REPO_ROOT/secrets.json")
  export SSH_USER=$(jq -r '.SSH_USER // empty' "$REPO_ROOT/secrets.json")
  export SSH_KEY_PATH=$(jq -r '.SSH_KEY_PATH // empty' "$REPO_ROOT/secrets.json")
  export BRIGHT_DATA_HOST=$(jq -r '.BRIGHT_DATA_HOST // empty' "$REPO_ROOT/secrets.json")
  export BRIGHT_DATA_PORT=$(jq -r '.BRIGHT_DATA_PORT // "22225"' "$REPO_ROOT/secrets.json")
  export BRIGHT_DATA_USER=$(jq -r '.BRIGHT_DATA_USER // empty' "$REPO_ROOT/secrets.json")
  export BRIGHT_DATA_PASS=$(jq -r '.BRIGHT_DATA_PASS // empty' "$REPO_ROOT/secrets.json")
  export WIREGUARD_PORT=$(jq -r '.WIREGUARD_PORT // "51820"' "$REPO_ROOT/secrets.json")
  export XRAY_PORT=$(jq -r '.XRAY_PORT // "1080"' "$REPO_ROOT/secrets.json")
  export WG_CLIENT_IP=$(jq -r '.WG_CLIENT_IP // "10.66.66.2"' "$REPO_ROOT/secrets.json")
  export WG_SERVER_IP=$(jq -r '.WG_SERVER_IP // "10.66.66.1"' "$REPO_ROOT/secrets.json")
fi

[[ -z "${SSH_HOST:-}" || -z "${SSH_USER:-}" ]] && { echo "Set SSH_HOST and SSH_USER."; exit 1; }

target="${SSH_USER}@${SSH_HOST}"
ssh_cmd() {
  if [[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]]; then
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "$target" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new "$target" "$@"
  fi
}
scp_from() {
  local remote="$1" local_path="$2"
  if [[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]]; then
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "${target}:${remote}" "$local_path"
  else
    scp -o StrictHostKeyChecking=accept-new "${target}:${remote}" "$local_path"
  fi
}

# Remove existing WG config so remote-install regenerates keys
ssh_cmd "sudo rm -f /etc/wireguard/wg0.conf"
# Re-upload and run remote-install (use same flow as setup-server.sh)
CREDS_FILE="$REPO_ROOT/tmp/creds.env"
mkdir -p "$(dirname "$CREDS_FILE")"
cat > "$CREDS_FILE" << EOF
SSH_HOST=${SSH_HOST:-}
SSH_USER=${SSH_USER:-}
BRIGHT_DATA_HOST=${BRIGHT_DATA_HOST:-}
BRIGHT_DATA_PORT=${BRIGHT_DATA_PORT:-22225}
BRIGHT_DATA_USER=${BRIGHT_DATA_USER:-}
BRIGHT_DATA_PASS=${BRIGHT_DATA_PASS:-}
WIREGUARD_PORT=${WIREGUARD_PORT:-51820}
XRAY_PORT=${XRAY_PORT:-1080}
WG_CLIENT_IP=${WG_CLIENT_IP:-10.66.66.2}
WG_SERVER_IP=${WG_SERVER_IP:-10.66.66.1}
EOF

ssh_cmd "mkdir -p $REMOTE_BASE/scripts $REMOTE_BASE/templates"
scp -o StrictHostKeyChecking=accept-new ${SSH_KEY_PATH:+-i "$SSH_KEY_PATH"} "$REPO_ROOT/scripts/remote-install.sh" "${target}:$REMOTE_BASE/scripts/remote-install.sh"
scp -o StrictHostKeyChecking=accept-new ${SSH_KEY_PATH:+-i "$SSH_KEY_PATH"} "$CREDS_FILE" "${target}:/tmp/claude-proxy-creds.env"
for f in "$REPO_ROOT/templates/"*.tpl; do
  [[ -f "$f" ]] && scp -o StrictHostKeyChecking=accept-new ${SSH_KEY_PATH:+-i "$SSH_KEY_PATH"} "$f" "${target}:$REMOTE_BASE/templates/$(basename "$f")"
done
ssh_cmd "chmod +x $REMOTE_BASE/scripts/remote-install.sh && sudo bash $REMOTE_BASE/scripts/remote-install.sh /tmp/claude-proxy-creds.env"

mkdir -p "$REPO_ROOT/out"
scp_from "/opt/claude-proxy/out/claude-wg-client.conf" "$REPO_ROOT/out/claude-wg-client.conf"
scp_from "/opt/claude-proxy/out/xray-client.json" "$REPO_ROOT/out/xray-client.json"
rm -f "$CREDS_FILE"
echo "New client configs in $REPO_ROOT/out. Re-import WireGuard and Xray client on your desktop."

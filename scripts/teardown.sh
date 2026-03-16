#!/usr/bin/env bash
# Remove WireGuard and Xray from the Vultr server. Does not destroy the server.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$REPO_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$REPO_ROOT/.env"
  set +a
elif [[ -f "$REPO_ROOT/secrets.json" ]] && command -v jq &>/dev/null; then
  export SSH_HOST=$(jq -r '.SSH_HOST' "$REPO_ROOT/secrets.json")
  export SSH_USER=$(jq -r '.SSH_USER' "$REPO_ROOT/secrets.json")
  export SSH_KEY_PATH=$(jq -r '.SSH_KEY_PATH // empty' "$REPO_ROOT/secrets.json")
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

ssh_cmd "sudo systemctl stop wg-quick@wg0 2>/dev/null; sudo systemctl disable wg-quick@wg0 2>/dev/null; sudo rm -f /etc/wireguard/wg0.conf"
ssh_cmd "sudo systemctl stop xray 2>/dev/null; sudo systemctl disable xray 2>/dev/null; sudo rm -f /usr/local/etc/xray/config.json"
ssh_cmd "sudo rm -rf /opt/claude-proxy"
echo "WireGuard and Xray removed from server."

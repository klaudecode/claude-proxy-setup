#!/usr/bin/env bash
# Run from repo root. Reads .env, uploads scripts + templates + creds to Vultr, runs remote-install, pulls client configs to ./out
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/out"
CREDS_FILE="$REPO_ROOT/tmp/creds.env"
REMOTE_BASE="/tmp/claude-proxy"

source_creds() {
  if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$REPO_ROOT/.env"
    set +a
    return
  fi
  if [[ -f "$REPO_ROOT/secrets.json" ]] && command -v jq &>/dev/null; then
    export SSH_HOST SSH_USER SSH_KEY_PATH BRIGHT_DATA_HOST BRIGHT_DATA_PORT BRIGHT_DATA_USER BRIGHT_DATA_PASS
    SSH_HOST=$(jq -r '.SSH_HOST // empty' "$REPO_ROOT/secrets.json")
    SSH_USER=$(jq -r '.SSH_USER // empty' "$REPO_ROOT/secrets.json")
    SSH_KEY_PATH=$(jq -r '.SSH_KEY_PATH // empty' "$REPO_ROOT/secrets.json")
    BRIGHT_DATA_HOST=$(jq -r '.BRIGHT_DATA_HOST // empty' "$REPO_ROOT/secrets.json")
    BRIGHT_DATA_PORT=$(jq -r '.BRIGHT_DATA_PORT // empty' "$REPO_ROOT/secrets.json")
    BRIGHT_DATA_USER=$(jq -r '.BRIGHT_DATA_USER // empty' "$REPO_ROOT/secrets.json")
    BRIGHT_DATA_PASS=$(jq -r '.BRIGHT_DATA_PASS // empty' "$REPO_ROOT/secrets.json")
    WIREGUARD_PORT=$(jq -r '.WIREGUARD_PORT // "51820"' "$REPO_ROOT/secrets.json")
    XRAY_PORT=$(jq -r '.XRAY_PORT // "1080"' "$REPO_ROOT/secrets.json")
    WG_CLIENT_IP=$(jq -r '.WG_CLIENT_IP // "10.66.66.2"' "$REPO_ROOT/secrets.json")
    WG_SERVER_IP=$(jq -r '.WG_SERVER_IP // "10.66.66.1"' "$REPO_ROOT/secrets.json")
    return
  fi
  echo "Create .env or secrets.json from the example files and set credentials."
  exit 1
}

build_creds_file() {
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
}

ssh_cmd() {
  local target="${SSH_USER}@${SSH_HOST}"
  if [[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]]; then
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "$target" "$@"
  else
    ssh -o StrictHostKeyChecking=accept-new "$target" "$@"
  fi
}

scp_to() {
  local src="$1" dest="$2"
  local target="${SSH_USER}@${SSH_HOST}"
  if [[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]]; then
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "$src" "${target}:${dest}"
  else
    scp -o StrictHostKeyChecking=accept-new "$src" "${target}:${dest}"
  fi
}

scp_from() {
  local remote="$1" local_path="$2"
  local target="${SSH_USER}@${SSH_HOST}"
  if [[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]]; then
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=accept-new "${target}:${remote}" "$local_path"
  else
    scp -o StrictHostKeyChecking=accept-new "${target}:${remote}" "$local_path"
  fi
}

source_creds
[[ -z "${SSH_HOST:-}" || -z "${SSH_USER:-}" ]] && { echo "SSH_HOST and SSH_USER required."; exit 1; }
build_creds_file

ssh_cmd "mkdir -p $REMOTE_BASE/scripts $REMOTE_BASE/templates"
scp_to "$REPO_ROOT/scripts/remote-install.sh" "$REMOTE_BASE/scripts/remote-install.sh"
scp_to "$CREDS_FILE" "/tmp/claude-proxy-creds.env"
for f in "$REPO_ROOT/templates/"*.tpl; do
  [[ -f "$f" ]] && scp_to "$f" "$REMOTE_BASE/templates/$(basename "$f")"
done

ssh_cmd "chmod +x $REMOTE_BASE/scripts/remote-install.sh && sudo bash $REMOTE_BASE/scripts/remote-install.sh /tmp/claude-proxy-creds.env"

mkdir -p "$OUT_DIR"
scp_from "/opt/claude-proxy/out/claude-wg-client.conf" "$OUT_DIR/claude-wg-client.conf"
scp_from "/opt/claude-proxy/out/xray-client.json" "$OUT_DIR/xray-client.json"

rm -f "$CREDS_FILE"
echo "Done. Client configs in: $OUT_DIR"
echo "  - claude-wg-client.conf -> import into WireGuard"
echo "  - xray-client.json      -> use with v2rayN/Nekoray; SOCKS5 at 127.0.0.1:1080"
echo "Set Claude app proxy to: socks5://127.0.0.1:1080"

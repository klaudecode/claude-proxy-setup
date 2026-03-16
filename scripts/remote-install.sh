#!/usr/bin/env bash
# Run on Vultr server. Sourced vars: SSH_HOST, WIREGUARD_PORT, XRAY_PORT,
# WG_SERVER_IP, WG_CLIENT_IP, BRIGHT_DATA_* from /tmp/claude-proxy-creds.env
# Run as root or with sudo.
set -euo pipefail
SUDO=""
[[ "$(id -u)" -eq 0 ]] || SUDO="sudo"

CREDS="${1:-/tmp/claude-proxy-creds.env}"
# When run on server, script lives under /tmp/claude-proxy/scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="/opt/claude-proxy/out"
CONF_DIR="/opt/claude-proxy"
MAIN_IF="${MAIN_INTERFACE:-eth0}"

if [[ ! -f "$CREDS" ]]; then
  echo "Missing credentials file: $CREDS"
  exit 1
fi
# shellcheck source=/dev/null
source "$CREDS"

export WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"
export XRAY_PORT="${XRAY_PORT:-1080}"
export WG_SERVER_IP="${WG_SERVER_IP:-10.66.66.1}"
export WG_CLIENT_IP="${WG_CLIENT_IP:-10.66.66.2}"

mkdir -p "$OUT_DIR" "$CONF_DIR"

# --- WireGuard ---
if ! command -v wg &>/dev/null; then
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq wireguard
fi

WG_CONF="/etc/wireguard/wg0.conf"
if [[ ! -f "$WG_CONF" ]] || grep -q "ReplaceMe" "$WG_CONF" 2>/dev/null; then
  WG_SERVER_PRIVATE=$(wg genkey)
  WG_SERVER_PUBLIC=$(echo "$WG_SERVER_PRIVATE" | wg pubkey)
  WG_CLIENT_PRIVATE=$(wg genkey)
  WG_CLIENT_PUBLIC=$(echo "$WG_CLIENT_PRIVATE" | wg pubkey)

  sed -e "s|__WG_SERVER_PRIVATE_KEY__|$WG_SERVER_PRIVATE|g" \
      -e "s|__WG_SERVER_PUBLIC_KEY__|$WG_SERVER_PUBLIC|g" \
      -e "s|__WG_CLIENT_PRIVATE_KEY__|$WG_CLIENT_PRIVATE|g" \
      -e "s|__WG_CLIENT_PUBLIC_KEY__|$WG_CLIENT_PUBLIC|g" \
      -e "s|__WG_SERVER_IP__|$WG_SERVER_IP|g" \
      -e "s|__WG_CLIENT_IP__|$WG_CLIENT_IP|g" \
      -e "s|__WIREGUARD_PORT__|$WIREGUARD_PORT|g" \
      -e "s|__SSH_HOST__|${SSH_HOST:-localhost}|g" \
      -e "s|eth0|$MAIN_IF|g" \
      "$BASE_DIR/templates/wg0.conf.tpl" | $SUDO tee "$WG_CONF" >/dev/null
  $SUDO chmod 600 "$WG_CONF"

  sed -e "s|__WG_SERVER_PUBLIC_KEY__|$WG_SERVER_PUBLIC|g" \
      -e "s|__WG_CLIENT_PRIVATE_KEY__|$WG_CLIENT_PRIVATE|g" \
      -e "s|__WG_CLIENT_IP__|$WG_CLIENT_IP|g" \
      -e "s|__WIREGUARD_PORT__|$WIREGUARD_PORT|g" \
      -e "s|__SSH_HOST__|${SSH_HOST:-localhost}|g" \
      "$BASE_DIR/templates/wg-client.conf.tpl" > "$OUT_DIR/claude-wg-client.conf"
  $SUDO chmod 600 "$OUT_DIR/claude-wg-client.conf"
  echo "WireGuard keys and configs generated."
else
  # Export existing client config (keys already in wg0.conf)
  cp "$WG_CONF" /tmp/wg0-read.conf 2>/dev/null || true
  echo "WireGuard already configured; skipping key generation. Re-run with key rotation to regenerate."
fi

# --- Xray ---
if ! command -v xray &>/dev/null; then
  bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" || true
  if ! command -v xray &>/dev/null; then
    echo "Xray install failed; you may need to install manually."
    exit 1
  fi
fi

XRAY_CFG="/usr/local/etc/xray/config.json"
sed -e "s|__WG_SERVER_IP__|$WG_SERVER_IP|g" \
    -e "s|__XRAY_PORT__|$XRAY_PORT|g" \
    -e "s|__BRIGHT_DATA_HOST__|${BRIGHT_DATA_HOST:-}|g" \
    -e "s|__BRIGHT_DATA_PORT__|${BRIGHT_DATA_PORT:-22225}|g" \
    -e "s|__BRIGHT_DATA_USER__|${BRIGHT_DATA_USER:-}|g" \
    -e "s|__BRIGHT_DATA_PASS__|${BRIGHT_DATA_PASS:-}|g" \
    "$BASE_DIR/templates/xray-server.json.tpl" | $SUDO tee "$XRAY_CFG" >/dev/null
$SUDO mkdir -p "$(dirname "$XRAY_CFG")"
$SUDO systemctl enable xray 2>/dev/null || true
$SUDO systemctl restart xray 2>/dev/null || true

# --- Xray client config (for desktop) ---
sed -e "s|__XRAY_SERVER_ADDRESS__|$WG_SERVER_IP|g" \
    -e "s|__XRAY_PORT__|$XRAY_PORT|g" \
    "$BASE_DIR/templates/xray-client.json.tpl" > "$OUT_DIR/xray-client.json"
$SUDO chmod 600 "$OUT_DIR/xray-client.json"

# --- Firewall ---
if command -v ufw &>/dev/null; then
  $SUDO ufw allow "$WIREGUARD_PORT/udp" 2>/dev/null || true
  $SUDO ufw --force enable 2>/dev/null || true
elif command -v iptables &>/dev/null; then
  $SUDO iptables -C INPUT -p udp --dport "$WIREGUARD_PORT" -j ACCEPT 2>/dev/null || $SUDO iptables -A INPUT -p udp --dport "$WIREGUARD_PORT" -j ACCEPT
fi

# --- Start WireGuard ---
$SUDO systemctl enable wg-quick@wg0 2>/dev/null || true
$SUDO systemctl restart wg-quick@wg0 2>/dev/null || true

echo "Done. Client configs in $OUT_DIR: claude-wg-client.conf, xray-client.json"

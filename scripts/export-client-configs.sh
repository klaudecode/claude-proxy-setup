#!/usr/bin/env bash
# Re-export client configs from server to ./out (after setup has been run once)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/out"

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

[[ -z "${SSH_HOST:-}" || -z "${SSH_USER:-}" ]] && { echo "Set SSH_HOST and SSH_USER in .env or secrets.json"; exit 1; }

target="${SSH_USER}@${SSH_HOST}"
scp_cmd=(scp -o StrictHostKeyChecking=accept-new)
[[ -n "${SSH_KEY_PATH:-}" ]] && [[ -f "$SSH_KEY_PATH" ]] && scp_cmd+=(-i "$SSH_KEY_PATH")

mkdir -p "$OUT_DIR"
"${scp_cmd[@]}" "${target}:/opt/claude-proxy/out/claude-wg-client.conf" "$OUT_DIR/"
"${scp_cmd[@]}" "${target}:/opt/claude-proxy/out/xray-client.json" "$OUT_DIR/"
echo "Exported to $OUT_DIR"

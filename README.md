# Claude proxy setup (Vultr + WireGuard + Xray + Bright Data)

Automated one-time setup so **only Claude** uses a stable proxy; other apps and browser stay on your normal connection.

**→ [Step-by-step guide](STEP-BY-STEP.md)** — follow this for a full walkthrough from credentials to Claude using the proxy.

## What you need

- **Existing Vultr server** (Ubuntu/Debian) with root or sudo SSH access
- **Bright Data** proxy credentials (zone host, port, user, password)
- **OpenSSH** on your PC (Windows 10+ has it; or use WSL/Git Bash for the Bash script)
- **Optional:** `jq` if you use `secrets.json` with the Bash script

## Quick start

1. **Clone or copy** this folder somewhere (e.g. `claude-proxy-setup`).

2. **Credentials** — copy the example and fill in:
   - **Windows (PowerShell):**  
     `Copy-Item .env.example .env` then edit `.env`
   - **Or** copy `secrets.json.example` to `secrets.json` and edit

   Required:
   - `SSH_HOST` — Vultr server IP
   - `SSH_USER` — e.g. `root`
   - `SSH_KEY_PATH` — path to your private key (e.g. `C:\Users\You\.ssh\id_ed25519`)  
     **or** set `SSH_PASSWORD` (less secure)
   - `BRIGHT_DATA_HOST`, `BRIGHT_DATA_PORT`, `BRIGHT_DATA_USER`, `BRIGHT_DATA_PASS` — from Bright Data zone

3. **Run setup** (from the repo root):
   - **PowerShell:**  
     `.\scripts\Setup-Server.ps1`
   - **Bash (WSL/Git Bash):**  
     `chmod +x scripts/setup-server.sh && ./scripts/setup-server.sh`

4. **On your PC:**
   - Import `out/claude-wg-client.conf` into **WireGuard for Windows** and activate.
   - Run **v2rayN** or **Nekoray** with `out/xray-client.json`; it will listen on `127.0.0.1:1080` (SOCKS5).
   - Double-click **`launch-claude-with-proxy.bat`** to start Claude with the proxy.

Traffic path: **Claude → SOCKS5 proxy (localhost:1080) → WireGuard → Vultr (Xray) → Bright Data → internet.**  
Only Claude uses this path; browser and other apps are unchanged.

## Helper batch files

| File | Purpose |
|------|---------|
| `launch-claude-with-proxy.bat` | Start Claude desktop app routed through the proxy |
| `Switch-To-Full-Tunnel.bat` | Route ALL traffic through VPN (for login, same IP as Claude) |
| `Switch-To-Claude-Only.bat` | Switch back to Claude-only routing |
| `Pull-Configs-Now.bat` | Re-run server setup and pull fresh configs |
| `Add-SSH-Key-To-Server.bat` | Add your SSH public key to the Vultr server |

## Re-export client configs

If you re-run the server install or only need to pull configs again:

- **PowerShell:**  
  `.\scripts\Export-ClientConfigs.ps1`  
  (Reads `.env` or `secrets.json`; copies from server `/opt/claude-proxy/out/` to local `./out/`.)

- **Bash:**  
  `./scripts/export-client-configs.sh`  
  (Same; uses `.env` or `secrets.json`.)

Or re-run full setup: `.\scripts\Setup-Server.ps1` / `./scripts/setup-server.sh`.

## Single IP / single device

For a **stable exit IP** and one “device” as seen by Anthropic, use a Bright Data product that gives a **sticky or static IP** (e.g. static residential or dedicated datacenter proxy). Set those credentials in `.env` / `secrets.json` and run the setup once.

## Security

- Do not commit `.env` or `secrets.json` (they are in `.gitignore`).
- Prefer SSH key over password.
- Client configs in `out/` are sensitive; keep them local.

## Optional: main interface

If your Vultr server uses an interface other than `eth0` (e.g. `ens3`), set on the server before or in the creds file:

```bash
export MAIN_INTERFACE=ens3
```

Then run the install; the WireGuard template uses this for NAT.

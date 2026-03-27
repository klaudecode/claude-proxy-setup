# Step-by-Step Setup: Claude Proxy

Follow these steps on a **new machine**. You only provide credentials; the scripts do the rest.

---

## Prerequisites

- A **Vultr server** (Ubuntu/Debian) that's already been set up with WireGuard + Xray (the server-side setup only needs to run once — if your server is already configured, skip to step 3)
- A **BrightData** account with ISP proxy credentials
- **Windows 10/11** with OpenSSH (built-in)

---

## Step 1: Install tools

1. Install **WireGuard for Windows**: https://www.wireguard.com/install/
2. That's it — everything else is included in this repo.

---

## Step 2: Set your credentials

1. Open this folder in a terminal:
   ```powershell
   cd "C:\path\to\claude-proxy-setup"
   ```

2. Copy the example file:
   ```powershell
   Copy-Item .env.example .env
   ```

3. Open `.env` in a text editor and fill in:

   | Variable | What to put |
   |----------|-------------|
   | `SSH_HOST` | Your Vultr server IP (e.g. `108.61.69.62`) |
   | `SSH_USER` | Usually `root` |
   | `SSH_KEY_PATH` | Path to your SSH private key (e.g. `C:\Users\You\.ssh\id_ed25519`) |
   | `BRIGHT_DATA_HOST` | From BrightData (e.g. `brd.superproxy.io`) |
   | `BRIGHT_DATA_PORT` | From BrightData (e.g. `33335`) |
   | `BRIGHT_DATA_USER` | Your BrightData zone username |
   | `BRIGHT_DATA_PASS` | Your BrightData zone password |

4. Save and close.

---

## Step 3: Run setup

```powershell
.\scripts\Full-Setup.ps1
```

This will:
- Download Xray core for Windows (into `xray/`)
- SSH into your Vultr server and install WireGuard + Xray (if not already done)
- Download client configs to `out/`
- Generate a **unique WireGuard key pair** for this machine
- Add this machine as a new peer on the server
- Import the WireGuard tunnel
- Configure Cursor's proxy setting

If the server is already set up (from another machine), the script detects that and only generates a new peer for this machine.

**If you don't have an SSH key yet:**
```powershell
ssh-keygen -t ed25519
```
Then add it to your Vultr server, or use `SSH_PASSWORD` in `.env` for the first run.

---

## Step 4: Configure Claude Desktop

Claude Desktop needs to be launched with a flag each time:

- **Double-click** `launch-claude-with-proxy.bat`

Or manually:
```
"C:\path\to\claude.exe" --proxy-server=socks5://127.0.0.1:1080
```

**Important:** Use `socks5://`, not `http://`. Cloudflare blocks HTTP proxies on claude.ai.

---

## Step 5: Configure Cursor (automatic)

The setup script adds this to Cursor's `settings.json`:
```json
{
  "http.proxy": "socks5://127.0.0.1:1080",
  "http.proxyStrictSSL": false
}
```

If you need to set it manually: **Cursor Settings → search "proxy"** → set to `socks5://127.0.0.1:1080`.

---

## Step 6: Configure Claude Code (optional)

If you use Claude Code (CLI), add to `~\.claude\settings.json`:
```json
{
  "env": {
    "HTTPS_PROXY": "socks5://127.0.0.1:1080",
    "HTTP_PROXY": "socks5://127.0.0.1:1080",
    "NO_PROXY": "localhost,127.0.0.1"
  }
}
```

---

## Daily Startup

1. **Double-click** `Start-Proxy.bat` (starts WireGuard + Xray)
2. **Double-click** `launch-claude-with-proxy.bat` (opens Claude)
3. Open **Cursor** normally

To stop: **double-click** `Stop-Proxy.bat`

---

## Deploying to another machine

1. Clone this repo on the new machine
2. Install WireGuard
3. Fill in `.env` with the same server credentials
4. Run `.\scripts\Full-Setup.ps1`
5. The script generates a unique WireGuard key pair for the new machine and adds it as a new peer on the server (e.g. 10.66.66.4)

Each machine gets its own IP on the WireGuard subnet. They can all run simultaneously.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| WireGuard handshake never completes | Each machine needs its own key pair. Check `wg show` on the server — if the peer endpoint shows a different IP, another machine is using the same key. |
| Claude shows "Couldn't connect" | Make sure you launched with `socks5://` (not `http://`). Cloudflare blocks HTTP proxies. |
| Xray crashes immediately | Run `xray\xray.exe run -config out\xray-client.json` in a terminal to see the error. |
| "Permission denied" on WireGuard | WireGuard tunnel install needs admin. Right-click `Start-Proxy.bat` → Run as administrator. |
| Cursor not using proxy | Restart Cursor after changing settings.json. |

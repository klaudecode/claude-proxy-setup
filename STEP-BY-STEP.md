# Step-by-step guide: Claude proxy (Vultr + WireGuard + Xray + Bright Data)

Follow these steps in order. You only need to provide credentials; the scripts do the rest.

---

## Before you start

- You have a **Vultr server** (Ubuntu or Debian) and can SSH into it (as root or a user with sudo).
- You have **Bright Data** account and proxy credentials (host, port, username, password).
- On your Windows PC: **OpenSSH** is available (Windows 10/11: Settings → Apps → Optional features → OpenSSH Client). Or use **WSL** or **Git Bash** for the Bash script.

---

## Step 1: Get the setup folder

- Clone this repo (or copy the folder) to your machine.
- Open a terminal and go to the repo root, e.g.:
  ```powershell
  cd "C:\Users\You\claude-proxy-setup"
  ```
  (Use your actual path to the cloned repo.)

---

## Step 2: Create your credentials file

**Option A — Using `.env` (recommended)**

1. Copy the example file:
   ```powershell
   Copy-Item .env.example .env
   ```
2. Open `.env` in a text editor and replace the placeholders:

   | Variable | What to put |
   |----------|-------------|
   | `SSH_HOST` | Your Vultr server IP (e.g. `123.45.67.89`) |
   | `SSH_USER` | SSH user, usually `root` |
   | `SSH_KEY_PATH` | Full path to your SSH private key (e.g. `C:\Users\You\.ssh\id_ed25519`). Leave empty if you use password. |
   | `SSH_PASSWORD` | Only if you don't use a key (less secure) |
   | `BRIGHT_DATA_HOST` | From Bright Data (e.g. `brd.superproxy.io`) |
   | `BRIGHT_DATA_PORT` | From Bright Data (e.g. `22225`) |
   | `BRIGHT_DATA_USER` | Your Bright Data zone username |
   | `BRIGHT_DATA_PASS` | Your Bright Data zone password |

3. Optional: change `WIREGUARD_PORT` (default `51820`) or `XRAY_PORT` (default `1080`) if you need to.
4. Save and close `.env`.

**Option B — Using `secrets.json`**

1. Copy the example:
   ```powershell
   Copy-Item secrets.json.example secrets.json
   ```
2. Open `secrets.json` and fill in the same values as in the table above (use the same names as in the example file).
3. Save and close.

---

## Step 3: Run the setup script

This will connect to your Vultr server, install WireGuard and Xray, configure Bright Data, and download client configs to the `out` folder.

**On Windows (PowerShell):**

```powershell
cd "C:\Users\You\claude-proxy-setup"
.\scripts\Setup-Server.ps1
```

**On WSL or Git Bash:**

```bash
cd /path/to/claude-proxy-setup
chmod +x scripts/setup-server.sh
./scripts/setup-server.sh
```

- If you see SSH host key prompts, type `yes` to accept.
- Wait until it finishes. You should see: "Done. Client configs saved to: …\out".

If it fails, check: correct IP, correct SSH user, key path (or password), and that the server is reachable (ping or try `ssh user@your-ip` in another terminal).

---

## Step 4: Install WireGuard on your PC

1. Download **WireGuard for Windows**: https://www.wireguard.com/install/
2. Install and open WireGuard.
3. Click **"Add tunnel"** → **"Import tunnel(s) from file"**.
4. Choose: `out\claude-wg-client.conf` (in this repo's `out` folder).
5. Click **"Activate"** to connect. The tunnel should show "Active".
6. Leave WireGuard running whenever you want Claude to use the proxy.

---

## Step 5: Install and run an Xray client on your PC

You need a local SOCKS5 proxy that connects to your Vultr server over the WireGuard tunnel.

**Option A — v2rayN (Windows)**

1. Download **v2rayN**: https://github.com/2dust/v2rayN/releases (e.g. `v2rayN-With-Core.zip`).
2. Unzip and run `v2rayN.exe`.
3. **Servers** → **Import bulk from config** (or **Import from config file**).
4. Select: `out\xray-client.json`.
5. In settings, ensure the local SOCKS port is **1080** (or note the port it uses).
6. Start the proxy (e.g. enable "Http proxy" / "Start core" so the SOCKS5 server is listening).
7. In v2rayN, set **System proxy** to **Off** (we only want Claude to use the proxy, not the whole system).

**Option B — Nekoray (Windows)**

1. Download **Nekoray**: https://github.com/MatsuriDayo/nekoray/releases.
2. Install and open. Import the config: **File** → **Import** → select `out\xray-client.json`.
3. Start the profile. Default SOCKS5 is usually `127.0.0.1:1080`.
4. Do **not** enable "System proxy" if you only want Claude to use it.

---

## Step 6: Set Claude to use the proxy

1. Make sure **WireGuard** is connected and the **Xray client** (v2rayN or Nekoray) is running.
2. Open **Claude** (desktop app).
3. Go to **Settings** (gear icon) → **Proxy** (or **Network**).
4. Enable proxy and set:
   - **Proxy URL:** `socks5://127.0.0.1:1080`  
   (If your Xray client uses a different port, use that instead, e.g. `socks5://127.0.0.1:2080`.)
5. Save. Claude's traffic will go: **Claude → Xray client (localhost) → WireGuard → Vultr (Xray) → Bright Data → internet.**

Your browser and other apps do **not** use this proxy unless you set a system-wide proxy.

---

## Step 7: Verify

1. In Claude, send a message that requires the internet (e.g. "What's the weather in Tokyo?").
2. If you get a normal reply, the proxy path is working.
3. To confirm the exit IP is from Bright Data, you can ask Claude: "What is my IP?" or use a site like https://api.ipify.org in a browser (browser will show your normal IP; only Claude uses the proxy).

---

## Quick reference: daily use

1. Start **WireGuard** and connect the "claude-wg" tunnel.
2. Start **v2rayN** (or Nekoray) and ensure the proxy is running.
3. Open **Claude**; proxy is already set to `socks5://127.0.0.1:1080`.
4. When done, you can disconnect WireGuard and close the Xray client; the rest of your PC keeps using your normal connection.

---

## Re-exporting configs (optional)

If you run setup again on the server or change something and want fresh client configs:

**PowerShell:**
```powershell
.\scripts\Export-ClientConfigs.ps1
```

**Bash:**
```bash
./scripts/export-client-configs.sh
```

New files will be in `out\`. Re-import the WireGuard config and Xray config in your clients if needed.

---

## Rotating keys (optional)

To regenerate WireGuard and client configs (e.g. for security):

**Bash only** (from repo root):
```bash
./scripts/rotate-keys.sh
```

Then re-import `out\claude-wg-client.conf` in WireGuard and `out\xray-client.json` in your Xray client.

---

## Removing the proxy from the server (optional)

To uninstall only WireGuard and Xray from the Vultr server (server stays):

**Bash:**
```bash
./scripts/teardown.sh
```

---

## Troubleshooting

| Problem | What to check |
|--------|----------------|
| Setup script can't connect | Correct `SSH_HOST`, `SSH_USER`, and key/password; server is on and reachable; firewall allows SSH (port 22). |
| WireGuard won't connect | Vultr firewall: allow UDP on `WIREGUARD_PORT` (default 51820). |
| Claude says proxy error | WireGuard is connected; Xray client is running; proxy in Claude is `socks5://127.0.0.1:1080` (or your Xray port). |
| No internet in Claude | Bright Data credentials in `.env`; Xray on server can reach Bright Data (check server logs). |

For more detail, see [README.md](README.md).

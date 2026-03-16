# Set up v2rayN + Xray on Windows

Use this after you have **WireGuard** connected and the **xray-client.json** from `out\` (from running the setup script).

---

## Option A: Automated install (recommended)

From the **cursor projects** repo folder, run:

```powershell
.\scripts\Install-V2rayN.ps1 -RepoRoot "C:\Users\Kyle\Documents\claude-proxy-setup"
```

This downloads v2rayN (with Xray core), extracts it to a folder, and opens it. Then do **Steps 2–4** below to import your config and start.

---

## Option B: Manual install

### 1. Download v2rayN (with Xray core)

1. Go to **https://github.com/2dust/v2rayN/releases**.
2. Download **v2rayN-windows64-With-Core.zip** or **v2rayN-windows-64-SelfContained.zip** (the one that includes the core).
3. Unzip to a folder, e.g. `C:\Users\Kyle\Documents\claude-proxy-setup\v2rayN`.

### 2. Set core to Xray

1. Run **v2rayN.exe** from the unzipped folder.
2. In the system tray, right‑click the v2rayN icon → **Settings** / **Parameter settings** (or open from the window).
3. Find **Core: core type** or **Core type** and set it to **Xray** (not V2Ray).
4. If it says “Download core” or “Update core”, do that so the Xray core is present. Save/close settings.

### 3. Import your config

1. In v2rayN: **Servers** → **Import bulk from config** or **Import from config file**.
2. Choose your **xray-client.json** from:
   - `C:\Users\Kyle\Documents\claude-proxy-setup\out\xray-client.json`
   - (Or wherever your setup wrote `out\`.)
3. The server should appear in the list (e.g. “proxy” or the first node). Select it.

### 4. Start the proxy (no system proxy)

1. **Http proxy** / **Start core** or **Enable proxy** so the core is running.
2. Leave **System proxy** **Off** so only Claude (and apps you choose) use the proxy.
3. v2rayN will listen as **SOCKS5** on **127.0.0.1:1080** (our client config uses port 1080).

### 5. Use with Claude

- Connect **WireGuard** (your Claude tunnel).
- Keep **v2rayN** running (core on, SOCKS5 on 1080).
- Launch Claude with the proxy launcher or set `HTTPS_PROXY=socks5://127.0.0.1:1080` when starting Claude.

---

## Summary

| Item        | Role                                      |
|------------|-------------------------------------------|
| **Xray**   | Core that runs the proxy (built into v2rayN). |
| **v2rayN** | Windows app: import config, start/stop, tray icon. |
| **xray-client.json** | Your config: SOCKS5 on 1080 → your Vultr server over WireGuard. |

You need **both** in the sense that v2rayN is the app and Xray is the engine it uses; the “With-Core” / “SelfContained” build gives you both in one install.

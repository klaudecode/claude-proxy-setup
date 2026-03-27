# Claude Proxy Setup (Vultr + WireGuard + Xray + BrightData)

Gives Claude Desktop and Cursor a **consistent exit IP** via BrightData, without touching system proxies or affecting your browser.

**Traffic path:**
```
Claude/Cursor → SOCKS5 (localhost:1080) → WireGuard → Vultr VPS → Xray → BrightData → Internet
```

Browser and other apps stay on your normal connection.

---

## Daily Startup (after first-time setup)

1. **Double-click** `Start-Proxy.bat` (starts WireGuard + Xray)
2. **Double-click** `launch-claude-with-proxy.bat` (opens Claude Desktop through the proxy)
3. Open **Cursor** normally (proxy is configured in settings.json)

**To stop:** double-click `Stop-Proxy.bat`

---

## First-Time Setup

See **[STEP-BY-STEP.md](STEP-BY-STEP.md)** for the full walkthrough.

**Quick version:**

1. Install [WireGuard for Windows](https://www.wireguard.com/install/)
2. Copy `.env.example` to `.env` and fill in your credentials
3. Run `.\scripts\Full-Setup.ps1` in PowerShell
4. Done — use the daily startup steps above

---

## Important Notes

- **Use SOCKS5, not HTTP proxy** — Cloudflare blocks HTTP CONNECT proxies on claude.ai. Always use `socks5://127.0.0.1:1080`.
- **Each machine needs its own WireGuard key pair** — the server supports multiple peers, each on a different IP (10.66.66.2, .3, .4, etc). Run setup on each machine.
- **No system proxy is changed** — only Claude and Cursor route through the tunnel.
- Do not commit `.env`, `secrets.json`, or files in `out/` (they contain keys).

---

## Files

| File | Purpose |
|------|---------|
| `Start-Proxy.bat` | Start WireGuard + Xray (daily) |
| `Stop-Proxy.bat` | Stop everything (daily) |
| `launch-claude-with-proxy.bat` | Open Claude Desktop through the proxy |
| `launch-cursor-with-proxy.bat` | Open Cursor through the proxy (optional, settings.json also works) |
| `scripts/Full-Setup.ps1` | One-click first-time setup |
| `scripts/Setup-Server.ps1` | Server-only setup (WireGuard + Xray on Vultr) |
| `scripts/Install-XrayCore.ps1` | Download Xray core for Windows |
| `.env` | Your credentials (not committed) |
| `out/` | Generated configs (not committed) |

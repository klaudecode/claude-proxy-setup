@echo off
echo Switching WireGuard to CLAUDE-ONLY tunnel (VPN subnet only)...
echo Browser uses your normal IP. Only Claude uses the proxy.
echo.
"C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice claude-wg-full 2>nul
"C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice claude-wg-client 2>nul
timeout /t 2 /nobreak >nul
"C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice "%~dp0out\claude-wg-client.conf"
echo.
echo Claude-only tunnel active. Browser uses normal connection.
pause

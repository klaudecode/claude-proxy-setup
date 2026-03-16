@echo off
echo Switching WireGuard to FULL tunnel (all traffic through VPN)...
echo Browser + Claude will share the same IP.
echo.
"C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice claude-wg-client 2>nul
"C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice claude-wg-full 2>nul
timeout /t 2 /nobreak >nul
"C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice "%~dp0out\claude-wg-full.conf"
echo.
echo Full tunnel active. All traffic goes through VPN.
echo To switch back to Claude-only, run: Switch-To-Claude-Only.bat
pause

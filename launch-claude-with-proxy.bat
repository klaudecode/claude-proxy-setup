@echo off
REM Launch Claude desktop app with proxy routing through VPN.
REM Requires: WireGuard (claude-wg-client) active + v2rayN running.
REM Only Claude traffic goes through the proxy. Browser and other apps are unaffected.

set "CLAUDE_EXE="

REM Try common install locations
for /f "delims=" %%i in ('powershell -NoProfile -Command "(Get-ChildItem 'C:\Program Files\WindowsApps\Claude_*\app\claude.exe' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName"') do set "CLAUDE_EXE=%%i"

if not defined CLAUDE_EXE (
    echo ERROR: Could not find claude.exe. Is Claude desktop installed?
    echo Download from: https://claude.ai/download
    pause
    exit /b 1
)

echo Starting Claude with proxy (socks5://127.0.0.1:1080)...
start "" "%CLAUDE_EXE%" --proxy-server=socks5://127.0.0.1:1080

@echo off
REM Launch Claude desktop app with proxy routing through VPN.
REM Requires: WireGuard (claude-wg-client) active.
REM Only Claude traffic goes through the proxy. Browser and other apps are unaffected.

for /f "delims=" %%i in ('powershell -NoProfile -Command "((Get-AppxPackage | Where-Object { $_.PackageFamilyName -like '*Claude*' }).InstallLocation + '\app\claude.exe')"') do set "CLAUDE_EXE=%%i"

if not exist "%CLAUDE_EXE%" (
    echo ERROR: Could not find claude.exe. Is Claude desktop installed?
    echo Download from: https://claude.ai/download
    pause
    exit /b 1
)

echo Starting Claude with proxy (socks5://127.0.0.1:1080)...
start "" "%CLAUDE_EXE%" --proxy-server=socks5://127.0.0.1:1080

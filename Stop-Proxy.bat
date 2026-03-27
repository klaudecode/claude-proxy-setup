@echo off
REM Stop the Claude/Cursor proxy (Xray + WireGuard).
REM Double-click this file to stop.

echo.
echo === Stopping Claude/Cursor Proxy ===
echo.

REM 1. Stop Xray
tasklist /fi "imagename eq xray.exe" 2>nul | find /i "xray.exe" >nul
if %errorlevel% equ 0 (
    echo Stopping Xray...
    taskkill /im xray.exe /f >nul 2>&1
    echo [OK] Xray stopped.
) else (
    echo [OK] Xray was not running.
)

REM 2. Stop WireGuard tunnel
sc query "WireGuardTunnel$claude-wg-client" >nul 2>&1
if %errorlevel% equ 0 (
    echo Stopping WireGuard tunnel...
    "C:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice claude-wg-client
    timeout /t 2 /nobreak >nul
    echo [OK] WireGuard tunnel stopped.
) else (
    echo [OK] WireGuard tunnel was not running.
)

echo.
echo === Proxy stopped ===
echo   Claude and Cursor will use your normal connection now.
echo.
pause

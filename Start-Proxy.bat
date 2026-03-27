@echo off
REM Start the Claude/Cursor proxy (WireGuard + Xray).
REM Double-click this file to start. No system proxy is changed.
REM Only Claude and Cursor use the proxy (via their own settings).

cd /d "%~dp0"

echo.
echo === Starting Claude/Cursor Proxy ===
echo.

REM 1. Check WireGuard tunnel
sc query "WireGuardTunnel$claude-wg-client" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] WireGuard tunnel is running.
) else (
    echo Starting WireGuard tunnel...
    if exist "out\claude-wg-client.conf" (
        "C:\Program Files\WireGuard\wireguard.exe" /installtunnelservice "%~dp0out\claude-wg-client.conf"
        timeout /t 4 /nobreak >nul
        sc query "WireGuardTunnel$claude-wg-client" >nul 2>&1
        if %errorlevel% equ 0 (
            echo [OK] WireGuard tunnel started.
        ) else (
            echo [WARN] Could not start WireGuard tunnel automatically.
            echo        Open WireGuard GUI and activate "claude-wg-client" manually.
        )
    ) else (
        echo [FAIL] out\claude-wg-client.conf not found. Run setup first.
        pause
        exit /b 1
    )
)

REM 2. Start Xray core (local SOCKS5 on 1080, HTTP on 1081)
tasklist /fi "imagename eq xray.exe" 2>nul | find /i "xray.exe" >nul
if %errorlevel% equ 0 (
    echo [OK] Xray is already running.
) else (
    if exist "xray\xray.exe" (
        echo Starting Xray core...
        start /b "" "xray\xray.exe" run -config "out\xray-client.json"
        timeout /t 3 /nobreak >nul
        tasklist /fi "imagename eq xray.exe" 2>nul | find /i "xray.exe" >nul
        if %errorlevel% equ 0 (
            echo [OK] Xray started (SOCKS5 on 127.0.0.1:1080).
        ) else (
            echo [FAIL] Xray did not start. Check out\xray-client.json.
            pause
            exit /b 1
        )
    ) else (
        echo [FAIL] xray\xray.exe not found. Run setup first.
        pause
        exit /b 1
    )
)

echo.
echo === Proxy is running ===
echo.
echo   SOCKS5 proxy: socks5://127.0.0.1:1080
echo   Exit IP:      consistent via BrightData
echo.
echo   Your browser and other apps are NOT affected.
echo   Only Claude and Cursor use this proxy.
echo.
echo   Next: launch Claude with "launch-claude-with-proxy.bat"
echo   To stop: double-click "Stop-Proxy.bat"
echo.
pause

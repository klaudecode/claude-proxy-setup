@echo off
REM Launch Cursor with proxy routing through the VPN tunnel.
REM Requires: WireGuard active + Xray running (use Start-Proxy.bat first).
REM Only Cursor traffic goes through the proxy. Browser and other apps are unaffected.

set "CURSOR_EXE="

REM Check common install locations
for %%p in (
    "%LOCALAPPDATA%\Programs\cursor\Cursor.exe"
    "%LOCALAPPDATA%\cursor\Cursor.exe"
    "%ProgramFiles%\Cursor\Cursor.exe"
) do (
    if exist %%p set "CURSOR_EXE=%%~p"
)

if "%CURSOR_EXE%"=="" (
    echo ERROR: Could not find Cursor.exe.
    echo Checked: LocalAppData\Programs\cursor, LocalAppData\cursor, Program Files\Cursor
    echo If Cursor is installed elsewhere, edit this file and set CURSOR_EXE.
    pause
    exit /b 1
)

echo Starting Cursor with proxy (socks5://127.0.0.1:1080)...
start "" "%CURSOR_EXE%" --proxy-server=socks5://127.0.0.1:1080

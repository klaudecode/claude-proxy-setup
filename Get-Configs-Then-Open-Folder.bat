@echo off
cd /d "%~dp0"
echo Pulling configs from server...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0scripts\Export-ClientConfigs.ps1' -RepoRoot '%~dp0'"
echo.
if exist "out\claude-wg-client.conf" (
  echo Configs are in: %~dp0out
  explorer "out"
) else (
  echo Failed to pull configs. Check .env and server status.
)
pause

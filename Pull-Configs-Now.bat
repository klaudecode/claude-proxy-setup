@echo off
cd /d "%~dp0"
echo ============================================
echo  Claude Proxy Setup
echo ============================================
echo.
echo You will be asked for your Vultr root password TWICE:
echo   1) When installing on the server (SSH)
echo   2) When downloading the config files (SCP)
echo.
echo Get the password from: Vultr dashboard - your server - Overview - Password
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0scripts\Setup-Server.ps1' -RepoRoot '%~dp0'"
echo.
if exist "out\claude-wg-client.conf" (
  echo ============================================
  echo  SUCCESS - Files are in: %~dp0out
  echo ============================================
  explorer "out"
) else (
  echo ============================================
  echo  FAILED - configs not found
  echo  Check .env has correct SSH_HOST, SSH_USER
  echo  and that the password is correct
  echo ============================================
)
pause

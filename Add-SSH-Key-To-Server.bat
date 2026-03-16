@echo off
cd /d "%~dp0"
echo ============================================
echo  Adding your SSH key to the Vultr server
echo ============================================
echo.
echo You will be asked for the ROOT PASSWORD one last time.
echo Get it from: Vultr dashboard - your server - Overview - Password
echo After this, all future connections use the SSH key (no more password).
echo.
echo NOTE: If the server was JUST created, wait 1-2 minutes for it to fully boot.
echo.

REM Read SSH_HOST from .env
for /f "tokens=1,* delims==" %%a in ('findstr /B "SSH_HOST" .env 2^>nul') do set "SSH_HOST=%%b"

if not defined SSH_HOST (
    echo ERROR: SSH_HOST not found in .env
    pause
    exit /b 1
)

echo Server: %SSH_HOST%
echo.
set /p dummy=Press Enter when ready...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$pubKey = Get-Content '%USERPROFILE%\.ssh\id_ed25519.pub' -Raw; $cmd = 'mkdir -p ~/.ssh && echo \"' + $pubKey.Trim() + '\" >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo KEY_INSTALLED_OK'; ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 root@%SSH_HOST% $cmd"
echo.
echo If you saw KEY_INSTALLED_OK above, the key is installed.
echo You can now run Pull-Configs-Now.bat without typing a password.
pause

@echo off
setlocal enabledelayedexpansion

:: Find ssh.exe
set SSH_CMD=ssh.exe
where ssh.exe >nul 2>&1
if %errorlevel% neq 0 (
  if exist "%WINDIR%\System32\OpenSSH\ssh.exe" set SSH_CMD="%WINDIR%\System32\OpenSSH\ssh.exe"
  if exist "%ProgramFiles%\OpenSSH\bin\ssh.exe" set SSH_CMD="%ProgramFiles%\OpenSSH\bin\ssh.exe"
)

echo Using SSH: !SSH_CMD!

:: Create startup task (runs at boot as SYSTEM, hidden)
schtasks /create /tn "CashManagerTunnel" /tr "!SSH_CMD! -o StrictHostKeyChecking=accept-new -R 80:localhost:8080 serveo.net" /sc onstart /delay 0000:15 /ru SYSTEM /rl highest /f

:: Also create logon task as fallback
schtasks /create /tn "CashManagerTunnel_User" /tr "!SSH_CMD! -o StrictHostKeyChecking=accept-new -R 80:localhost:8080 serveo.net" /sc onlogon /delay 0000:10 /f

echo Tunnel service installed. It will auto-start on next boot.
exit /b 0

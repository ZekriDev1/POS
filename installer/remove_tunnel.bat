@echo off
schtasks /delete /tn "CashManagerTunnel" /f >nul 2>&1
schtasks /delete /tn "CashManagerTunnel_User" /f >nul 2>&1
exit /b 0

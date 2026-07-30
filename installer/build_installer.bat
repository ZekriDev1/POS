@echo off
cd /d "%~dp0.."

echo Building Flutter Windows app...
call flutter build windows --release
if %errorlevel% neq 0 (
  echo Flutter build failed.
  exit /b 1
)

echo Compiling installer with Inno Setup...
set ISCC="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist %ISCC% (
  echo Inno Setup not found at %ISCC%
  echo Download from: https://jrsoftware.org/isdl.php
  echo.
  echo After installing, run this again, or manually compile:
  echo   installer\installer.iss
  exit /b 1
)

%ISCC% installer\installer.iss
if %errorlevel% equ 0 (
  echo Installer created: installer\output\CashManagerPOS_Setup_0.2.0.exe
) else (
  echo Installer compilation failed.
  exit /b 1
)

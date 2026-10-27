@echo off
setlocal
title campus-wifi-autologin - Uninstall

REM Double-click this file to remove campus-wifi-autologin completely.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath \"%~f0\" -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"

echo.
echo Press any key to close this window.
pause >nul

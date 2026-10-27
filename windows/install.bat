@echo off
setlocal
title campus-wifi-autologin - Install

REM ---------------------------------------------------------------------------
REM  Double-click this file to install or reconfigure campus-wifi-autologin.
REM  It asks for Administrator rights, unblocks the downloaded files and runs
REM  Install.ps1 without touching the system-wide PowerShell execution policy.
REM ---------------------------------------------------------------------------

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath \"%~f0\" -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%~dp0' -Recurse | Unblock-File"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"

echo.
echo Press any key to close this window.
pause >nul

@echo off
setlocal DisableDelayedExpansion
title campus-wifi-autologin - Uninstall

REM Double-click this file to remove campus-wifi-autologin completely.

set "CW_DIR=%~dp0"
set "CW_SELF=%~f0"

if not exist "%CW_DIR%Uninstall.ps1" goto :not_extracted

net session >nul 2>&1
if errorlevel 1 goto :elevate
goto :run

:elevate
echo Requesting Administrator rights - click "Yes" on the Windows prompt...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process -FilePath $env:CW_SELF -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
if errorlevel 1 goto :elevation_denied
exit /b 0

:run
cd /d "%CW_DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%CW_DIR%Uninstall.ps1"
goto :end

:not_extracted
echo.
echo  Uninstall.ps1 was not found next to uninstall.bat.
echo  Extract the ZIP first (right-click  ^>  Extract All...), then run uninstall.bat again.
goto :end

:elevation_denied
echo.
echo  Administrator rights were not granted, so nothing was removed.

:end
echo.
echo Press any key to close this window.
pause >nul

@echo off
setlocal DisableDelayedExpansion
title campus-wifi-autologin - Status

REM Double-click to see whether auto-login is installed and working.
REM Does not need Administrator rights.

set "CW_DIR=%~dp0"
if not exist "%CW_DIR%Status.ps1" goto :not_extracted
powershell -NoProfile -ExecutionPolicy Bypass -File "%CW_DIR%Status.ps1"
goto :end

:not_extracted
echo Status.ps1 was not found. Extract the ZIP first, then run status.bat again.

:end
echo.
echo Press any key to close this window.
pause >nul

@echo off
setlocal DisableDelayedExpansion
title campus-wifi-autologin - Install

REM Double-click this file to install or reconfigure campus-wifi-autologin.
REM
REM Paths are only ever expanded outside ( ) blocks and handed to PowerShell
REM through environment variables, so folder names such as
REM "campus-wifi-autologin-master (1)" or names containing & and ' work.

set "CW_DIR=%~dp0"
set "CW_SELF=%~f0"

if not exist "%CW_DIR%Install.ps1" goto :not_extracted

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
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath $env:CW_DIR -Recurse | Unblock-File"
powershell -NoProfile -ExecutionPolicy Bypass -File "%CW_DIR%Install.ps1"
if errorlevel 1 goto :failed
goto :end

:not_extracted
echo.
echo  Install.ps1 was not found next to install.bat.
echo.
echo  If you opened the ZIP file directly, extract it first:
echo    right-click the ZIP  ^>  Extract All...  ^>  Extract,
echo  then open the extracted "windows" folder and run install.bat again.
goto :end

:elevation_denied
echo.
echo  Administrator rights were not granted, so nothing was installed.
echo  Run install.bat again and click "Yes" on the Windows prompt.
goto :end

:failed
echo.
echo  Installation did not finish. See the message above.

:end
echo.
echo Press any key to close this window.
pause >nul

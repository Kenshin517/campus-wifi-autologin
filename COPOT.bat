@echo off
REM ============================================================
REM  Copot auto-login WiFi kampus PENS
REM  Cukup DOBEL-KLIK file ini.
REM ============================================================

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Meminta akses Administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
echo Mencopot auto-login WiFi kampus...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
echo.
echo Selesai. Tekan tombol apa saja untuk menutup.
pause >nul

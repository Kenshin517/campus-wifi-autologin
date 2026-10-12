@echo off
REM ============================================================
REM  Launcher setup auto-login WiFi kampus PENS
REM  Cukup DOBEL-KLIK file ini. Tidak perlu buka PowerShell.
REM ============================================================

REM --- Minta akses Administrator otomatis (popup UAC) ---
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Meminta akses Administrator...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

echo ============================================
echo   Setup Auto-Login WiFi Kampus PENS
echo ============================================
echo.

REM --- Unblock semua file (hapus tanda 'downloaded from internet') ---
powershell -NoProfile -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File"

REM --- Jalankan setup dengan bypass execution policy ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo ============================================
echo   Selesai. Tekan tombol apa saja untuk menutup.
echo ============================================
pause >nul

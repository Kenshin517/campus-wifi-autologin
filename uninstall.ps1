# ============================================================
# Uninstall auto-login WiFi kampus
# ============================================================
# Menghapus Task Scheduler + config.ps1. Jalankan kalau mau copot.
# ============================================================

$taskName  = "Auto Login Wifi Kampus"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.ps1"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[OK] Task '$taskName' dihapus." -ForegroundColor Green
} else {
    Write-Host "[INFO] Task '$taskName' tidak ditemukan." -ForegroundColor Yellow
}

if (Test-Path $configPath) {
    Remove-Item $configPath -Force
    Write-Host "[OK] config.ps1 dihapus." -ForegroundColor Green
}

Write-Host "Uninstall selesai." -ForegroundColor Green

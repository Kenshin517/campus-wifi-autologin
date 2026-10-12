# ============================================================
# Setup auto-login WiFi kampus PENS
# ============================================================
# Jalankan SEKALI. Script ini akan:
#   1. Minta NetID & password kamu
#   2. Simpan ke config.ps1 (password ter-enkripsi DPAPI)
#   3. Daftarkan Task Scheduler dengan 2 trigger:
#        - On event: tiap konek ke jaringan baru
#        - Daily 00:05: jaga-jaga reset sesi tengah malam
#
# Cara pakai: klik kanan file ini > Run with PowerShell
#   atau di PowerShell: .\setup.ps1
# ============================================================

$ErrorActionPreference = "Stop"
$taskName  = "Auto Login Wifi Kampus"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptDir "connect-campus-wifi.ps1"
$configPath = Join-Path $scriptDir "config.ps1"

Write-Host "=== Setup Auto-Login WiFi Kampus PENS ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $mainScript)) {
    Write-Host "ERROR: connect-campus-wifi.ps1 tidak ada di folder yang sama." -ForegroundColor Red
    Write-Host "Pastikan kamu menjalankan setup.ps1 dari dalam folder repo." -ForegroundColor Red
    exit 1
}

# ---- 1. Minta kredensial ----
$netID = Read-Host "Masukkan NetID kamu"
$securePass = Read-Host "Masukkan Password kamu" -AsSecureString
# DPAPI: hasil enkripsi cuma bisa didekripsi oleh user + mesin yang sama
$encryptedPass = ConvertFrom-SecureString $securePass

# ---- 2. Tulis config.ps1 ----
$configContent = @"
# File ini dibuat otomatis oleh setup.ps1 -- JANGAN commit ke git.
# Password di bawah ter-enkripsi DPAPI (cuma bisa dibaca di akun & PC ini).
`$CampusNetID = "$netID"
`$CampusPassEncrypted = "$encryptedPass"
"@
# Tulis tanpa BOM (ASCII) biar dot-source di PowerShell 5.1 bersih.
[System.IO.File]::WriteAllText($configPath, $configContent, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "[OK] config.ps1 tersimpan (password ter-enkripsi)." -ForegroundColor Green

# ---- 3. Daftarkan Task Scheduler ----
# Hapus task lama kalau sudah ada (biar idempotent)
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[INFO] Task lama dengan nama sama dihapus, dibuat ulang." -ForegroundColor Yellow
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$mainScript`""

# Trigger 1: tiap kali konek ke jaringan (event NetworkProfile 10000)
$class = Get-CimClass -Namespace Root/Microsoft/Windows/TaskScheduler -ClassName MSFT_TaskEventTrigger
$eventTrigger = New-CimInstance -CimClass $class -ClientOnly
$eventTrigger.Enabled = $true
$eventTrigger.Subscription = @"
<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]</Select></Query></QueryList>
"@

# Trigger 2: tiap hari jam 00:05 (jaga-jaga reset sesi tengah malam)
$dailyTrigger = New-ScheduledTaskTrigger -Daily -At "00:05"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger @($eventTrigger, $dailyTrigger) `
    -Settings $settings `
    -Principal $principal `
    -Description "Auto-login captive portal WiFi kampus PENS (eepiswlan)" | Out-Null

Write-Host "[OK] Task Scheduler '$taskName' terdaftar (2 trigger)." -ForegroundColor Green
Write-Host ""

# ---- 4. Test langsung ----
Write-Host "Menjalankan test sekali..." -ForegroundColor Cyan
& powershell.exe -ExecutionPolicy Bypass -File $mainScript
Start-Sleep -Seconds 2
$logFile = Join-Path $scriptDir "autologin.log"
if (Test-Path $logFile) {
    Write-Host ""
    Write-Host "=== Isi log terakhir ===" -ForegroundColor Cyan
    Get-Content $logFile -Tail 5
}

Write-Host ""
Write-Host "Selesai! Script akan jalan otomatis tiap konek WiFi kampus." -ForegroundColor Green
Write-Host "Kalau ganti password, jalankan ulang setup.ps1." -ForegroundColor Green

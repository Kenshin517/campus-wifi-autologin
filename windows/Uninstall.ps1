<#
.SYNOPSIS
    Removes campus-wifi-autologin from Windows.

.DESCRIPTION
    Unregisters the scheduled task (and the v1 task, if still present) and deletes
    C:\ProgramData\CampusWifiAutologin, including the saved credentials and log.
    Normally launched by uninstall.bat. Requires Administrator.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:ProgramData 'CampusWifiAutologin'

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Administrator rights are required. Please run uninstall.bat instead.' -ForegroundColor Red
    exit 1
}

foreach ($name in @('CampusWifiAutologin', 'Auto Login Wifi Kampus')) {
    if (Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $name -Confirm:$false
        Write-Host "[OK] Removed scheduled task '$name'" -ForegroundColor Green
    }
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host "[OK] Deleted $InstallDir (credentials and log)" -ForegroundColor Green
}

Write-Host ''
Write-Host 'campus-wifi-autologin has been uninstalled.' -ForegroundColor Green

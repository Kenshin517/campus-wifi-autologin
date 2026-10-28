<#
.SYNOPSIS
    Shows whether campus-wifi-autologin is installed and working.

.DESCRIPTION
    Reads the state written by the background task (last check, network, result),
    the scheduled task details when available, and the last log lines.
    Does not require Administrator rights. Normally launched by status.bat.

.NOTES
    Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
#>
[CmdletBinding()]
param()

$InstallDir = Join-Path $env:ProgramData 'CampusWifiAutologin'
$StatePath  = Join-Path $InstallDir 'state.json'
$LogPath    = Join-Path $InstallDir 'autologin.log'
$TaskName   = 'CampusWifiAutologin'
$Invariant  = [Globalization.CultureInfo]::InvariantCulture

function Write-Field([string]$Label, [string]$Value, [string]$Color = 'Gray') {
    Write-Host ('  {0,-14}: ' -f $Label) -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

Write-Host ''
Write-Host '  campus-wifi-autologin  |  status' -ForegroundColor White
Write-Host '  --------------------------------'

if (-not (Test-Path -LiteralPath $InstallDir)) {
    Write-Field 'Installed' 'NO - run install.bat first' 'Red'
    exit 1
}
Write-Field 'Installed' "yes ($InstallDir)" 'Green'

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
    $color = if ($task.State -eq 'Disabled') { 'Red' } else { 'Green' }
    Write-Field 'Background task' "$($task.State)" $color
    if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -gt 2000) {
        Write-Field 'Task last ran' $info.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss', $Invariant)
    }
} else {
    Write-Field 'Background task' 'not visible (missing, or needs Administrator to view)' 'Yellow'
}

if (Test-Path -LiteralPath $StatePath) {
    $state = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    $last = [datetime]::ParseExact($state.LastCheck, 'yyyy-MM-dd HH:mm:ss', $Invariant)
    $age = (Get-Date) - $last
    $ageText = if ($age.TotalMinutes -lt 1) { 'just now' } else { '{0:N0} min ago' -f $age.TotalMinutes }
    $ageColor = if ($age.TotalMinutes -gt 10) { 'Yellow' } else { 'Green' }
    Write-Field 'Last check' "$($state.LastCheck) ($ageText)" $ageColor
    if ($age.TotalMinutes -gt 10) {
        Write-Host '                  The task normally checks every 3 minutes. If this stays old,' -ForegroundColor Yellow
        Write-Host '                  run install.bat again.' -ForegroundColor Yellow
    }
    $net = if ($state.Ssid) { $state.Ssid } else { 'unknown' }
    Write-Field 'Network' $net
    $resultText = switch ($state.LastResult) {
        'online'        { 'online - no login needed' }
        'logged-in'     { 'logged in by this tool' }
        'other-network' { 'not on campus Wi-Fi - nothing to do' }
        'rejected'      { 'portal REJECTED the password - run install.bat again' }
        'failed'        { 'login failed - will retry automatically' }
        default         { $state.LastResult }
    }
    $resultColor = if ($state.LastResult -in @('rejected', 'failed')) { 'Red' } else { 'Green' }
    Write-Field 'Last result' $resultText $resultColor
    if ($state.LastLogin) { Write-Field 'Last auto-login' $state.LastLogin }
} else {
    Write-Field 'Last check' 'none yet (the task has not run since install)' 'Yellow'
}

Write-Host ''
Write-Host '  Recent log:' -ForegroundColor White
$tail = Get-Content -LiteralPath $LogPath -Tail 10 -ErrorAction SilentlyContinue
if ($tail) { $tail | ForEach-Object { Write-Host "    $_" } }
else       { Write-Host '    (empty)' }
Write-Host ''
Write-Host "  Full log: $LogPath"

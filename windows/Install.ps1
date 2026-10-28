<#
.SYNOPSIS
    Installs (or reconfigures) campus-wifi-autologin on Windows.

.DESCRIPTION
    - Asks for your NetID and password.
    - Copies the login script to C:\ProgramData\CampusWifiAutologin and locks the
      folder down (SYSTEM/Administrators full control, Users read-only).
    - Saves the credentials to config.json, with the password encrypted by DPAPI
      (LocalMachine scope) and the file readable only by SYSTEM/Administrators.
    - Registers the scheduled task "CampusWifiAutologin", running as SYSTEM:
        * at startup,
        * every time a network connects,
        * every 3 minutes (re-login after the portal drops the session,
          including the nightly reset).
    - Removes the task created by v1.x ("Auto Login Wifi Kampus"), if present.

    Normally launched by install.bat, which takes care of elevation and the
    execution policy. Requires Administrator.

.NOTES
    Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files as ANSI).
#>
[CmdletBinding()]
param(
    [string]$NetId,
    [SecureString]$Password,   # for unattended installs; prompted when omitted
    [string]$TargetSsid = 'eepiswlan'
)

$ErrorActionPreference = 'Stop'

$TaskName      = 'CampusWifiAutologin'
$LegacyTask    = 'Auto Login Wifi Kampus'
$InstallDir    = Join-Path $env:ProgramData 'CampusWifiAutologin'
$ScriptName    = 'CampusWifiAutologin.ps1'
$SourceScript  = Join-Path $PSScriptRoot $ScriptName
$TargetScript  = Join-Path $InstallDir $ScriptName
$ConfigPath    = Join-Path $InstallDir 'config.json'
$LogPath       = Join-Path $InstallDir 'autologin.log'
$Entropy       = [Text.Encoding]::UTF8.GetBytes('CampusWifiAutologin')

# Well-known SIDs, so this works on any Windows display language.
$SidSystem = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
$SidAdmins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
$SidUsers  = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')

function Write-Step([string]$Text) { Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Info([string]$Text) { Write-Host "[..] $Text" -ForegroundColor Cyan }

function Set-LockedAcl {
    param([string]$Path, [bool]$UsersCanRead)
    $isDir = (Get-Item -LiteralPath $Path).PSIsContainer
    $acl = if ($isDir) { New-Object Security.AccessControl.DirectorySecurity }
           else        { New-Object Security.AccessControl.FileSecurity }
    $acl.SetAccessRuleProtection($true, $false)   # no inherited permissions
    $inherit = if ($isDir) { 'ContainerInherit, ObjectInherit' } else { 'None' }

    $rules = @(
        @($SidSystem, 'FullControl'),
        @($SidAdmins, 'FullControl')
    )
    if ($UsersCanRead) { $rules += , @($SidUsers, 'ReadAndExecute') }

    foreach ($r in $rules) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule(
            $r[0], $r[1], $inherit, 'None', 'Allow')))
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

# ------------------------------------------------------------------------------
# Pre-flight
# ------------------------------------------------------------------------------
$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Administrator rights are required. Please run install.bat instead.' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $SourceScript)) {
    Write-Host "$ScriptName was not found next to Install.ps1. Run install.bat from the 'windows' folder." -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '  campus-wifi-autologin  |  Windows installer' -ForegroundColor White
Write-Host '  ------------------------------------------'
Write-Host ''

# ------------------------------------------------------------------------------
# 1. Credentials
# ------------------------------------------------------------------------------
while (-not $NetId) { $NetId = (Read-Host 'NetID').Trim() }

$plain = ''
while (-not $plain) {
    $secure = if ($Password) { $Password } else { Read-Host 'Password (input is hidden)' -AsSecureString }
    $Password = $null
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try   { $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

Add-Type -AssemblyName System.Security
$cipher = [Security.Cryptography.ProtectedData]::Protect(
    [Text.Encoding]::UTF8.GetBytes($plain), $Entropy,
    [Security.Cryptography.DataProtectionScope]::LocalMachine)
$plain = $null

# ------------------------------------------------------------------------------
# 2. Files
# ------------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}
Set-LockedAcl -Path $InstallDir -UsersCanRead $true

Copy-Item -LiteralPath $SourceScript -Destination $TargetScript -Force
Write-Step "Script installed to $InstallDir"

$config = [ordered]@{
    NetId             = $NetId
    PasswordEncrypted = [Convert]::ToBase64String($cipher)
    TargetSsid        = $TargetSsid
    PortalDomain      = 'pens.ac.id'
    MaxAttempts       = 6
    RetryDelay        = 10
} | ConvertTo-Json
[IO.File]::WriteAllText($ConfigPath, $config, (New-Object Text.UTF8Encoding($false)))
Set-LockedAcl -Path $ConfigPath -UsersCanRead $false
Write-Step 'Credentials saved (password encrypted, readable by SYSTEM/Administrators only)'

if (-not (Test-Path -LiteralPath $LogPath)) { New-Item -ItemType File -Path $LogPath | Out-Null }

# ------------------------------------------------------------------------------
# 3. Scheduled task
# ------------------------------------------------------------------------------
if (Get-ScheduledTask -TaskName $LegacyTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $LegacyTask -Confirm:$false
    Write-Step "Removed old v1 task '$LegacyTask'"
}

$eventQuery = '<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational">' +
              '<Select Path="Microsoft-Windows-NetworkProfile/Operational">' +
              "*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]" +
              '</Select></Query></QueryList>'
$eventQueryXml = [Security.SecurityElement]::Escape($eventQuery)
$argsXml = [Security.SecurityElement]::Escape(
    "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$TargetScript`"")
# Task XML needs ISO 8601; ':' in .NET formats is the *culture's* time separator (e.g. '.' on id-ID).
$start = (Get-Date).Date.ToString('s', [Globalization.CultureInfo]::InvariantCulture)

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>campus-wifi-autologin</Author>
    <Description>Automatically logs in to the PENS campus Wi-Fi captive portal. https://github.com/Kenshin517/campus-wifi-autologin</Description>
  </RegistrationInfo>
  <Triggers>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT30S</Delay>
    </BootTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>$eventQueryXml</Subscription>
      <Delay>PT5S</Delay>
    </EventTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT3M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$start</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>$argsXml</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Register-ScheduledTask -TaskName $TaskName -Xml $taskXml -Force | Out-Null
Write-Step "Scheduled task '$TaskName' registered (startup, on network connect, every 3 min)"

# ------------------------------------------------------------------------------
# 4. First run
# ------------------------------------------------------------------------------
# Forget the previous state so the first check always writes a visible log line.
Remove-Item -LiteralPath (Join-Path $InstallDir 'state.json') -ErrorAction SilentlyContinue
Write-Info 'Running a first check...'
Start-ScheduledTask -TaskName $TaskName
$deadline = (Get-Date).AddSeconds(90)
do {
    Start-Sleep -Seconds 2
    $state = (Get-ScheduledTask -TaskName $TaskName).State
} while ($state -eq 'Running' -and (Get-Date) -lt $deadline)

Write-Host ''
Write-Host '  Last log lines:' -ForegroundColor White
$tail = Get-Content -LiteralPath $LogPath -Tail 6 -ErrorAction SilentlyContinue
if ($tail) { $tail | ForEach-Object { Write-Host "    $_" } }
else       { Write-Host '    (nothing logged yet - run status.bat in a minute)' }

Write-Host ''
Write-Host '  Done. Auto-login is active and runs in the background.' -ForegroundColor Green
Write-Host "  Log file : $LogPath"
Write-Host '  Check it any time by double-clicking status.bat.'
Write-Host '  To change your password, run install.bat again.'
Write-Host ''

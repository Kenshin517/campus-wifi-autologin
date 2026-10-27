<#
.SYNOPSIS
    Automatically logs in to the PENS campus Wi-Fi captive portal (eepiswlan).

.DESCRIPTION
    Runs from Task Scheduler as SYSTEM (installed by Install.ps1). On every run it:
      1. Checks whether the machine is on the campus SSID.
      2. Checks whether the internet is already reachable.
      3. If not, discovers the captive portal URL from the redirect, submits
         the login form, and verifies connectivity.
    Every step is retried a few times, because right after Wi-Fi associates the
    network is often not ready yet (no DHCP lease, DNS not up, portal slow).

    Credentials are read from config.json next to this script. The password is
    encrypted with DPAPI (LocalMachine scope) and the file is readable only by
    SYSTEM and Administrators.

.PARAMETER Verbose
    Also log routine "already online / not on campus" checks.

.NOTES
    Project: https://github.com/Kenshin517/campus-wifi-autologin
    Keep this file ASCII-only: Windows PowerShell 5.1 reads BOM-less files as ANSI.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
# Invoke-WebRequest renders a progress bar by default, which makes it very slow
# (or hang) when running non-interactively from Task Scheduler.
$ProgressPreference = 'SilentlyContinue'

# ------------------------------------------------------------------------------
# Settings
# ------------------------------------------------------------------------------
$AppDir        = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath    = Join-Path $AppDir 'config.json'
$LogPath       = Join-Path $AppDir 'autologin.log'
$PortalCache   = Join-Path $AppDir 'portal-url.txt'
$LogMaxLines   = 500
$Entropy       = [Text.Encoding]::UTF8.GetBytes('CampusWifiAutologin')

$Defaults = @{
    TargetSsid   = 'eepiswlan'
    PortalDomain = 'pens.ac.id'
    MaxAttempts  = 6
    RetryDelay   = 10
}

# Probes that a captive portal intercepts and redirects (plain HTTP on purpose).
$ProbeUrls = @(
    'http://neverssl.com/',
    'http://www.msftconnecttest.com/redirect',
    'http://detectportal.firefox.com/canonical.html'
)

# ------------------------------------------------------------------------------
# Networking setup (Windows PowerShell 5.1 / .NET Framework defaults are old)
# ------------------------------------------------------------------------------
# Older .NET defaults may not offer TLS 1.2, which makes the HTTPS portal fail.
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.SecurityProtocolType]::Tls12 -bor `
    [Net.SecurityProtocolType]::Tls11 -bor `
    [Net.SecurityProtocolType]::Tls

# The portal uses an internal certificate. Accept certificate errors ONLY for
# hosts under the campus domain; everything else is validated normally.
if (-not ('CampusWifiCertPolicy' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class CampusWifiCertPolicy {
    public static string Domain = "pens.ac.id";

    private static bool Validate(object sender, X509Certificate cert, X509Chain chain, SslPolicyErrors errors) {
        if (errors == SslPolicyErrors.None) { return true; }
        HttpWebRequest req = sender as HttpWebRequest;
        if (req == null) { return false; }
        string host = req.RequestUri.Host;
        return host.Equals(Domain, StringComparison.OrdinalIgnoreCase)
            || host.EndsWith("." + Domain, StringComparison.OrdinalIgnoreCase);
    }

    public static void Install() {
        ServicePointManager.ServerCertificateValidationCallback = Validate;
    }
}
'@
}

Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Web

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
function Write-Log {
    param([Parameter(Mandatory)][string]$Message)
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    try {
        Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
        $lines = @(Get-Content -LiteralPath $LogPath -ErrorAction Stop)
        if ($lines.Count -gt $LogMaxLines) {
            $lines[(-$LogMaxLines)..-1] | Set-Content -LiteralPath $LogPath -Encoding UTF8
        }
    } catch { }
    Write-Verbose $line
}

function Get-Config {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "config.json not found in $AppDir. Run install.bat first."
    }
    $raw = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    $cipher = [Convert]::FromBase64String($raw.PasswordEncrypted)
    $plain  = [Security.Cryptography.ProtectedData]::Unprotect(
        $cipher, $Entropy, [Security.Cryptography.DataProtectionScope]::LocalMachine)

    $cfg = @{
        NetId    = [string]$raw.NetId
        Password = [Text.Encoding]::UTF8.GetString($plain)
    }
    foreach ($key in $Defaults.Keys) {
        $cfg[$key] = if ($raw.PSObject.Properties[$key]) { $raw.$key } else { $Defaults[$key] }
    }
    return $cfg
}

function Get-WifiSsid {
    <# Returns the connected SSID, or $null if it cannot be determined. #>

    # 1) netsh. On Windows 11 24H2+ this may require Location permission and
    #    then prints no SSID at all, so it is not the only source.
    try {
        $out = & netsh.exe wlan show interfaces 2>$null
        foreach ($line in $out) {
            if ($line -match '^\s*SSID\s*:\s*(.+?)\s*$') { return $Matches[1] }
        }
    } catch { }

    # 2) Network profile name. Windows names the profile after the SSID
    #    (sometimes with a suffix such as "eepiswlan 2").
    try {
        $profiles = Get-NetConnectionProfile -ErrorAction Stop |
            Where-Object { $_.InterfaceAlias -match 'Wi-?Fi|WLAN|Wireless' }
        foreach ($p in $profiles) {
            if ($p.Name) { return ($p.Name -replace '\s+\d+$', '') }
        }
    } catch { }

    return $null
}

function Test-Internet {
    $checks = @(
        @{ Url = 'http://www.msftconnecttest.com/connecttest.txt'; Body = 'Microsoft Connect Test'; Code = 200 },
        @{ Url = 'http://connectivitycheck.gstatic.com/generate_204'; Body = $null; Code = 204 }
    )
    foreach ($c in $checks) {
        try {
            $req = [Net.HttpWebRequest]::Create($c.Url)
            $req.AllowAutoRedirect = $false
            $req.Timeout = 5000
            $resp = $req.GetResponse()
            try {
                $code = [int]$resp.StatusCode
                $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
            } finally { $resp.Close() }
            if ($code -eq $c.Code -and (-not $c.Body -or $body -match [regex]::Escape($c.Body))) {
                return $true
            }
        } catch { }
    }
    return $false
}

function Test-PortalHost {
    param([string]$Url, [string]$Domain)
    if (-not $Url) { return $false }
    try { $h = ([Uri]$Url).Host } catch { return $false }
    return ($h -eq $Domain -or $h.EndsWith(".$Domain"))
}

function Find-PortalUrl {
    <#
        Asks a plain-HTTP probe URL and follows what the captive portal does:
        a 30x Location header, or (for some portals) an HTML/JS redirect in the
        body. Returns the first URL that points to the campus domain.
    #>
    param([string]$Domain)

    $urlPattern = 'https?://[A-Za-z0-9.-]*' + [regex]::Escape($Domain) + '[^"''<>\s]*'

    foreach ($probe in $ProbeUrls) {
        $url = $probe
        for ($hop = 0; $hop -lt 5; $hop++) {
            $resp = $null
            try {
                $req = [Net.HttpWebRequest]::Create($url)
                $req.AllowAutoRedirect = $false
                $req.Timeout = 8000
                try { $resp = $req.GetResponse() }
                catch [Net.WebException] { $resp = $_.Exception.Response }
                if (-not $resp) { break }

                $code     = [int]$resp.StatusCode
                $location = $resp.Headers['Location']
                $body     = ''
                try { $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() } catch { }
            } catch {
                break
            } finally {
                if ($resp) { $resp.Close() }
            }

            if ($code -ge 300 -and $code -lt 400 -and $location) {
                $url = ([Uri]::new([Uri]$url, $location)).AbsoluteUri
                continue
            }
            if (Test-PortalHost -Url $url -Domain $Domain) { return $url }

            $m = [regex]::Match($body, $urlPattern)
            if ($m.Success) { return [Web.HttpUtility]::HtmlDecode($m.Value) }
            break
        }
    }
    return $null
}

function Invoke-PortalLogin {
    <# Returns 'ok', 'rejected' (bad credentials) or 'error'. #>
    param([string]$LoginUrl, [hashtable]$Cfg)

    $query    = [Web.HttpUtility]::ParseQueryString(([Uri]$LoginUrl).Query)
    $redirurl = if ($query['redirurl']) { $query['redirurl'] } else { 'http://www.msftconnecttest.com/redirect' }

    # Field names of the PENS portal login form.
    $body = @{
        auth_user = $Cfg.NetId
        auth_pass = $Cfg.Password
        redirurl  = $redirurl
        accept    = 'Login'
    }
    if ($query['zone']) { $body['zone'] = $query['zone'] }

    try {
        $resp = Invoke-WebRequest -Uri $LoginUrl -Method Post -Body $body -UseBasicParsing -TimeoutSec 15
        Write-Log "Login form submitted (HTTP $($resp.StatusCode))."
        # Content is a byte[] when the portal sends no text Content-Type.
        $text = if ($resp.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($resp.Content) }
                else { [string]$resp.Content }
        if ($text -match '(?i)invalid|incorrect|wrong password|salah|gagal') {
            return 'rejected'
        }
        return 'ok'
    } catch {
        Write-Log "Login request failed: $($_.Exception.Message)"
        return 'error'
    }
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
$mutex = New-Object Threading.Mutex($false, 'Global\CampusWifiAutologin')
try { $acquired = $mutex.WaitOne(0) }
catch [Threading.AbandonedMutexException] { $acquired = $true }   # previous run was killed
if (-not $acquired) { exit 0 }   # another run is already in progress
$rejectedCount = 0

try {
    try { $cfg = Get-Config }
    catch { Write-Log "ERROR: $($_.Exception.Message)"; exit 1 }

    [CampusWifiCertPolicy]::Domain = $cfg.PortalDomain
    [CampusWifiCertPolicy]::Install()

    for ($attempt = 1; $attempt -le $cfg.MaxAttempts; $attempt++) {
        $ssid = Get-WifiSsid

        if ($ssid -and $ssid -ne $cfg.TargetSsid) {
            if ($VerbosePreference -ne 'SilentlyContinue') { Write-Log "Not on $($cfg.TargetSsid) (SSID: $ssid). Skipping." }
            exit 0
        }

        if (Test-Internet) {
            if ($attempt -gt 1) { Write-Log 'Internet is reachable.' }
            elseif ($VerbosePreference -ne 'SilentlyContinue') { Write-Log 'Already online.' }
            exit 0
        }

        if ($attempt -eq 1) {
            $label = if ($ssid) { $ssid } else { 'unknown SSID' }
            Write-Log "No internet on $label. Starting login (up to $($cfg.MaxAttempts) attempts)."
        }

        $portal = Find-PortalUrl -Domain $cfg.PortalDomain
        if ($portal) {
            Set-Content -LiteralPath $PortalCache -Value $portal -Encoding ASCII
        } elseif (Test-Path -LiteralPath $PortalCache) {
            $portal = (Get-Content -LiteralPath $PortalCache -Raw).Trim()
            Write-Log "Attempt ${attempt}: portal redirect not seen, using last known portal URL."
        }

        if (-not (Test-PortalHost -Url $portal -Domain $cfg.PortalDomain)) {
            # Without a known SSID, only act when the campus portal is actually seen.
            Write-Log "Attempt ${attempt}: captive portal not found yet (network may still be starting)."
            Start-Sleep -Seconds $cfg.RetryDelay
            continue
        }

        Write-Log "Attempt ${attempt}: portal $(([Uri]$portal).GetLeftPart([UriPartial]::Path))"
        $result = Invoke-PortalLogin -LoginUrl $portal -Cfg $cfg
        Start-Sleep -Seconds 3

        if (Test-Internet) {
            Write-Log 'SUCCESS: logged in, internet is reachable.'
            exit 0
        }
        if ($result -eq 'rejected') {
            $rejectedCount++
            # Stop early instead of hammering the portal with a wrong password.
            if ($rejectedCount -ge 2) {
                Write-Log 'Portal rejected the login twice. Check your NetID/password and run install.bat again.'
                exit 2
            }
        }
        Start-Sleep -Seconds $cfg.RetryDelay
    }

    Write-Log "FAILED after $($cfg.MaxAttempts) attempts. Will retry on the next scheduled run."
    exit 1
}
finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}

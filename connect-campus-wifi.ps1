# ============================================================
# Auto-login captive portal WiFi kampus PENS (eepiswlan)
# ============================================================
# Script ini TIDAK menyimpan kredensial. NetID & password dibaca
# dari config.ps1 (yang di-gitignore + password-nya ter-enkripsi
# DPAPI per-user per-mesin). Jalankan setup.ps1 dulu sekali untuk
# membuat config.ps1 dan mendaftarkan Task Scheduler.
# ============================================================

# Matiin progress bar Invoke-WebRequest -- kalau nggak, request bisa
# sangat lambat/nyangkut pas dijalankan headless lewat Task Scheduler.
$ProgressPreference = "SilentlyContinue"

$ErrorActionPreference = "Stop"

$targetSSID   = "eepiswlan"
$checkURL     = "http://www.msftconnecttest.com/connecttest.txt"
$expectedBody = "Microsoft Connect Test"
$scriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath   = Join-Path $scriptDir "config.ps1"
$logFile      = Join-Path $scriptDir "autologin.log"

# ---- Kompatibilitas sertifikat HTTPS (portal pakai cert internal) ----
if ($PSVersionTable.PSVersion.Major -lt 6) {
    Add-Type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
Add-Type -AssemblyName System.Web

function Write-Log {
    param([string]$msg)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logFile -Append -Encoding utf8

    # Jaga log biar nggak numpuk selamanya: simpan 200 baris terakhir saja.
    try {
        $lines = @(Get-Content -LiteralPath $logFile -ErrorAction Stop)
        if ($lines.Count -gt 200) {
            $lines[-200..-1] | Set-Content -LiteralPath $logFile -Encoding utf8
        }
    } catch { }
}

function Get-CurrentSSID {
    $result = netsh wlan show interfaces
    $ssidLine = $result | Select-String "^\s*SSID\s*:\s*(.+)$"
    if ($ssidLine) {
        return $ssidLine.Matches[0].Groups[1].Value.Trim()
    }
    return $null
}

function Test-InternetAccess {
    try {
        $response = Invoke-WebRequest -Uri $checkURL -UseBasicParsing -TimeoutSec 5
        return ($response.StatusCode -eq 200 -and $response.Content -match [regex]::Escape($expectedBody))
    } catch {
        return $false
    }
}

function Get-PortalLoginUrl {
    # Nembak URL plain-http yang biasa dipakai buat deteksi captive portal.
    # Kalau belum login, request ini di-redirect ke halaman login portal
    # (domain + zone + redirurl keikut otomatis di URL akhir). Dengan ini
    # kita nggak perlu hardcode domain (iac3 vs iac32 beda tergantung AP).
    try {
        $resp = Invoke-WebRequest -Uri "http://neverssl.com/" -MaximumRedirection 5 -UseBasicParsing -TimeoutSec 8
        return $resp.BaseResponse.ResponseUri.AbsoluteUri
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.ResponseUri) {
            return $_.Exception.Response.ResponseUri.AbsoluteUri
        }
        return $null
    }
}

function Connect-CaptivePortal {
    param([string]$netID, [string]$password)

    $loginUrl = Get-PortalLoginUrl
    if (-not $loginUrl) {
        Write-Log "Gagal menemukan URL captive portal (redirect tidak terdeteksi)."
        return
    }
    Write-Log "URL portal terdeteksi: $loginUrl"

    $uri = [Uri]$loginUrl
    $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
    $redirurl = $query["redirurl"]
    if (-not $redirurl) { $redirurl = $checkURL }

    # Field form sesuai hasil inspeksi portal PENS:
    # auth_user, auth_pass, redirurl, accept
    $body = @{
        auth_user = $netID
        auth_pass = $password
        redirurl  = $redirurl
        accept    = "Login"
    }

    try {
        $resp = Invoke-WebRequest -Uri $loginUrl -Method POST -Body $body -UseBasicParsing -TimeoutSec 10
        Write-Log "POST login terkirim ke $loginUrl, status: $($resp.StatusCode)"
    } catch {
        Write-Log "POST login gagal: $_"
    }
}

# ---- Main ----
if (-not (Test-Path $configPath)) {
    Write-Log "config.ps1 tidak ditemukan. Jalankan setup.ps1 dulu."
    exit 1
}

# config.ps1 mendefinisikan $CampusNetID dan $CampusPassEncrypted
. $configPath

try {
    $securePass = ConvertTo-SecureString $CampusPassEncrypted
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
    $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
} catch {
    Write-Log "Gagal dekripsi password dari config.ps1. Jalankan ulang setup.ps1 (DPAPI terikat ke user+mesin yang sama)."
    exit 1
}

$currentSSID = Get-CurrentSSID

if ($currentSSID -eq $targetSSID) {
    Write-Log "Terhubung ke $targetSSID, cek akses internet..."

    if (-not (Test-InternetAccess)) {
        Write-Log "Belum ada internet, coba auto-login..."
        Connect-CaptivePortal -netID $CampusNetID -password $plainPass
        Start-Sleep -Seconds 3

        if (Test-InternetAccess) {
            Write-Log "Berhasil connect ke internet kampus."
        } else {
            Write-Log "Masih belum konek. Cek URL portal & error di log di atas."
        }
    } else {
        Write-Log "Sudah ada akses internet, tidak perlu login ulang."
    }
} else {
    Write-Log "SSID saat ini '$currentSSID' bukan '$targetSSID', skip."
}

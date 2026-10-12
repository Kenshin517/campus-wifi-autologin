# Auto-Login WiFi Kampus PENS (eepiswlan)

Script PowerShell yang **otomatis login ke captive portal WiFi kampus PENS** setiap kali laptopmu konek ke `eepiswlan`. Nggak perlu lagi buka browser dan ketik NetID + password manual tiap pagi atau tiap sesi login expired.

Cara kerjanya: begitu laptop connect ke jaringan, script cek — kalau SSID-nya `eepiswlan` **dan** belum ada internet, dia submit form login portal otomatis di background. Kalau SSID lain (WiFi rumah, hotspot, dll) atau internet sudah jalan, dia langsung skip.

> Dibuat & dites di Windows 11. Perlu PowerShell 5.1+ (bawaan Windows).

---

## ✨ Fitur

- **Auto-login** tiap connect ke `eepiswlan`, tanpa buka browser.
- **Aman**: password nggak disimpan plaintext — di-enkripsi pakai DPAPI Windows (cuma bisa dibaca di akun & PC kamu sendiri), dan file kredensial di-`.gitignore`.
- **Deteksi domain portal otomatis** — kampus pakai beberapa domain (`iac3`, `iac32`, dst) tergantung access point; script nangkep yang aktif lewat redirect, nggak di-hardcode.
- **Dua trigger**: tiap connect jaringan + tiap hari jam 00:05 (portal kampus reset sesi tiap tengah malam).
- **Setup satu klik** lewat `setup.ps1` — bikin config + daftar Task Scheduler sekaligus.

---

## 🚀 Cara Pakai

### 1. Download repo ini
Klik tombol hijau **Code → Download ZIP**, lalu extract. Jika punya git:
```powershell
git clone https://github.com/USERNAME/campus-wifi-autologin.git
cd campus-wifi-autologin
```

### 2. Izinkan eksekusi script (sekali saja)
Buka **PowerShell**, jalankan:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Ketik `Y` kalau ditanya.

### 3. Jalankan setup
Di folder repo, jalankan:
```powershell
.\setup.ps1
```
Script akan:
1. Minta **NetID** dan **password** kamu (password tidak akan terlihat ketika diketik).
2. Simpan ke `config.ps1` (password ter-enkripsi).
3. Daftarkan Task Scheduler otomatis.
4. Langsung tes sekali & nunjukin log-nya.

Selesai! Mulai sekarang auto-login jalan sendiri.

---

## 🔧 Perintah Lain

| Mau apa | Jalankan |
|---|---|
| Ganti password / NetID | `.\setup.ps1` (jalankan ulang) |
| Copot semuanya | `.\uninstall.ps1` |
| Cek log | buka `autologin.log` di folder repo |
| Test manual | `.\connect-campus-wifi.ps1` |

---

## ❓ Troubleshooting

**"running scripts is disabled on this system"**
→ Belum jalanin langkah 2. Jalankan `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

**Log bilang "POST login gagal" atau status bukan 200**
→ Kemungkinan NetID/password salah. Jalankan ulang `.\setup.ps1`.

**Udah login tapi status Task "Running" terus**
→ Pastikan di Task Scheduler, tab Actions, Program-nya `powershell.exe` dan argument-nya pakai `-File`. `setup.ps1` sudah set ini otomatis, jadi harusnya aman.

**Mau tes dari kondisi "belum login" padahal sudah login**
→ Portal nyimpen sesi per-MAC address di server, bukan di laptop. Restart/forget network nggak reset. Cara paling cepat: aktifkan **Random hardware addresses** di Settings → WiFi → eepiswlan, lalu reconnect.

---

## 🔒 Catatan Keamanan

- `config.ps1` berisi kredensialmu dan **di-`.gitignore`** — nggak akan keupload ke GitHub.
- Password di `config.ps1` di-enkripsi DPAPI: ciphertext-nya cuma bisa didekripsi oleh akun Windows + mesin yang sama. Kalau file-nya dicopy ke PC lain, nggak kebaca.
- Tetap **jangan** commit `config.ps1` secara manual.

---

## ⚠️ Disclaimer

Script ini buat memudahkan login ke WiFi kampus pakai akun kamu sendiri yang sah. Pakai dengan tanggung jawab sendiri sesuai aturan jaringan kampus masing-masing.

---

## 📁 Struktur

```
campus-wifi-autologin/
├── connect-campus-wifi.ps1   # script utama (dipanggil Task Scheduler)
├── setup.ps1                 # installer: config + daftar task
├── uninstall.ps1             # copot task + hapus config
├── config.example.ps1        # contoh struktur config
├── .gitignore                # melindungi config.ps1 & log
└── README.md
```

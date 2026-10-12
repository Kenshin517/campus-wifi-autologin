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

## 🚀 Cara Pakai (CARA MUDAH — untuk semua orang)

### 1. Download repo ini
Klik tombol hijau **Code → Download ZIP**, lalu extract (klik kanan ZIP → Extract All).

### 2. Dobel-klik `JALANKAN.bat`
Buka folder hasil extract, lalu **dobel-klik file `JALANKAN.bat`**.
- Muncul popup Windows minta izin Administrator → klik **Yes**.
- Masukkan **NetID** dan **password** kamu (password tidak akan terlihat ketika diketik — itu normal, tinggal ketik lalu Enter).

Selesai! `JALANKAN.bat` otomatis mengurus semua izin Windows (execution policy, unblock file, admin), bikin config, dan daftar Task Scheduler. Mulai sekarang auto-login jalan sendiri tiap kamu konek WiFi kampus.

> Kalau Windows SmartScreen muncul ("Windows protected your PC"), klik **More info → Run anyway**. Ini wajar untuk file .bat yang baru di-download.

---

## 🛠️ Cara Manual (opsional, buat yang paham PowerShell)

Kalau lebih suka lewat PowerShell: buka **PowerShell as Administrator**, masuk ke folder repo, lalu:
```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
Jangan pakai `.\setup.ps1` langsung — file dari internet belum ter-sign jadi akan diblokir. Gunakan perintah `-ExecutionPolicy Bypass` di atas.

---

## 🔧 Perintah Lain

| Mau apa | Jalankan |
|---|---|
| Ganti password / NetID | dobel-klik `JALANKAN.bat` lagi |
| Copot semuanya | dobel-klik `COPOT.bat` |
| Cek log | buka `autologin.log` di folder repo |

---

## ❓ Troubleshooting

**"running scripts is disabled" / "is not digitally signed" / "Access is denied"**
→ Ini kejadian kalau jalanin `.\setup.ps1` langsung tanpa admin. Pakai `JALANKAN.bat` (cara mudah di atas) — semua masalah izin ini sudah ditangani otomatis.

**Windows SmartScreen: "Windows protected your PC"**
→ Klik **More info → Run anyway**. Wajar untuk file .bat baru.

**Log bilang "POST login gagal" atau status bukan 200**
→ Kemungkinan NetID/password salah. Jalankan ulang `JALANKAN.bat`.

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
├── JALANKAN.bat              # <- DOBEL-KLIK INI buat setup (cara mudah)
├── COPOT.bat                 # dobel-klik buat uninstall
├── connect-campus-wifi.ps1   # script utama (dipanggil Task Scheduler)
├── setup.ps1                 # installer: config + daftar task
├── uninstall.ps1             # copot task + hapus config
├── config.example.ps1        # contoh struktur config
├── .gitignore                # melindungi config.ps1 & log
└── README.md
```

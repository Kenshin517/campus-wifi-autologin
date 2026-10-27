# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-10-28

### Fixed
- Login sometimes failed right after connecting and had to be done manually. The
  script ran once, before DHCP/DNS/the portal were ready, and gave up. Each run now
  retries up to 6 times, 10 seconds apart.
- A session dropped by the portal during the day was only restored at the next
  reconnect. A periodic check (Windows: every 3 min, Linux: every 2 min) now
  restores it automatically.
- HTTPS to the portal could fail on systems where Windows PowerShell does not enable
  TLS 1.2 by default.
- SSID detection failed on Windows 11 24H2+ without Location permission; the
  network profile name and the portal domain are now used as fallbacks.

### Added
- Linux support: `campus-wifi-autologin` CLI, systemd service and timer,
  NetworkManager dispatcher hook, `install.sh`, and a `.deb` package with debconf setup.
- Portal URL discovery from several probe URLs, including HTML/JS redirects, with the
  last known portal URL as a fallback.
- Early stop when the portal rejects the credentials twice.
- CI: ShellCheck, `.deb` build and install test, PSScriptAnalyzer.

### Changed
- Repository restructured into `windows/` and `linux/`; documentation in English.
- Windows: runs as `SYSTEM` from `C:\ProgramData\CampusWifiAutologin` (no console
  window flashes, works before logon). The password is encrypted with machine-scope
  DPAPI and the config is readable only by SYSTEM and Administrators.
- Windows: `JALANKAN.bat` / `COPOT.bat` renamed to `install.bat` / `uninstall.bat`.
  The v1 scheduled task is removed automatically on install.
- TLS certificate errors are accepted only for hosts under the portal domain.
- Routine checks are no longer logged.

## [1.0.0] - 2026-10-16

- First release: Windows PowerShell script with Task Scheduler triggers and
  DPAPI-encrypted credentials.

[2.0.0]: https://github.com/Kenshin517/campus-wifi-autologin/releases/tag/v2.0.0
[1.0.0]: https://github.com/Kenshin517/campus-wifi-autologin/commit/a098326

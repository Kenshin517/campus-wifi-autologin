# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project follows [Semantic Versioning](https://semver.org/).

## [2.0.2] - 2026-10-28

### Fixed
- Windows: double-clicking `install.bat` / `uninstall.bat` did nothing (window flashed
  and closed) when the folder name contained `)`, e.g. `campus-wifi-autologin-master (1)`
  after downloading the ZIP twice. The launchers no longer expand paths inside `( )`
  blocks and always pause with an explanation on failure.
- Running `install.bat` from inside an unextracted ZIP now says to extract it first.
- The log stayed empty when no login was needed (portal session still valid), so it
  looked as if nothing ran. A line is now logged whenever the situation changes, and
  the time of the last check is always recorded.

### Added
- `windows\status.bat`: shows install state, background task, last check, last result
  and recent log lines without Administrator rights.
- Linux: `campus-wifi-autologin status` shows the last check time.
- CI runs the launchers from a folder named `... (1) & it's` and checks that the first
  run writes a status line.

## [2.0.1] - 2026-10-28

### Fixed
- Windows installer failed with `0x80041318 ... StartBoundary:2026-10-28T00.00.00` on
  systems with an Indonesian (or any '.'-time-separator) locale, leaving no scheduled
  task registered. Dates are now formatted culture-invariantly.

### Added
- `Install.ps1 -Password` for unattended installs.
- CI installs and uninstalls the Windows version under the `id-ID` locale.

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

[2.0.2]: https://github.com/Kenshin517/campus-wifi-autologin/compare/7ddacf1...master
[2.0.1]: https://github.com/Kenshin517/campus-wifi-autologin/commit/e5632dc
[2.0.0]: https://github.com/Kenshin517/campus-wifi-autologin/commit/5dd791d
[1.0.0]: https://github.com/Kenshin517/campus-wifi-autologin/commit/a098326

#!/usr/bin/env bash
#
# Install campus-wifi-autologin from a git checkout.
#   sudo ./install.sh
#
# Installs the CLI to /usr/local/bin, a systemd service + timer (or a cron
# entry on systems without systemd) and a NetworkManager dispatcher hook,
# then asks for your NetID and password.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN=/usr/local/bin/campus-wifi-autologin
UNIT_DIR=/etc/systemd/system
NM_HOOK=/etc/NetworkManager/dispatcher.d/90-campus-wifi-autologin

info() { printf '\033[1;32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!!]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || fail "Run with sudo: sudo ./install.sh"
command -v curl >/dev/null 2>&1 || fail "curl is required. Install it first, e.g.: sudo apt install curl"
command -v flock >/dev/null 2>&1 || fail "flock (util-linux) is required."
if ! command -v nmcli >/dev/null 2>&1 && ! command -v iwgetid >/dev/null 2>&1 && ! command -v iw >/dev/null 2>&1; then
    warn "None of nmcli/iwgetid/iw found: the SSID cannot be detected, the tool will rely on seeing the campus portal."
fi

HAS_SYSTEMD=0
if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    HAS_SYSTEMD=1
elif ! command -v crontab >/dev/null 2>&1; then
    fail "Neither systemd nor cron is available, nothing can run the check periodically."
fi

if dpkg-query -W -f='${Status}' campus-wifi-autologin 2>/dev/null | grep -q 'install ok installed'; then
    fail "The .deb package is already installed. Use 'sudo campus-wifi-autologin setup' or remove the package first."
fi

install -Dm755 "$SRC/bin/campus-wifi-autologin" "$BIN"
info "Installed $BIN"

if [ -d /etc/NetworkManager ]; then
    install -Dm755 "$SRC/networkmanager/90-campus-wifi-autologin" "$NM_HOOK"
    info "Installed NetworkManager hook $NM_HOOK"
fi

if [ "$HAS_SYSTEMD" -eq 1 ]; then
    sed "s#/usr/bin/campus-wifi-autologin#$BIN#" "$SRC/systemd/campus-wifi-autologin.service" \
        >"$UNIT_DIR/campus-wifi-autologin.service"
    install -m644 "$SRC/systemd/campus-wifi-autologin.timer" "$UNIT_DIR/campus-wifi-autologin.timer"
    systemctl daemon-reload
    info "Installed systemd service + timer"
else
    warn "systemd not detected, falling back to cron (every 2 minutes)."
    ( crontab -l 2>/dev/null | grep -v 'campus-wifi-autologin' || true
      echo "*/2 * * * * $BIN run >/dev/null 2>&1"
      echo "@reboot sleep 30 && $BIN run >/dev/null 2>&1" ) | crontab -
    info "Installed cron entries"
fi

echo
"$BIN" setup

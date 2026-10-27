#!/usr/bin/env bash
#
# Remove a campus-wifi-autologin installation made with install.sh.
#   sudo ./uninstall.sh            # keep config and log
#   sudo ./uninstall.sh --purge    # also delete credentials and log

set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo ./uninstall.sh" >&2; exit 1; }

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl disable --now campus-wifi-autologin.timer 2>/dev/null || true
    rm -f /etc/systemd/system/campus-wifi-autologin.service /etc/systemd/system/campus-wifi-autologin.timer
    systemctl daemon-reload
fi
if command -v crontab >/dev/null 2>&1; then
    ( crontab -l 2>/dev/null | grep -v 'campus-wifi-autologin' || true ) | crontab -
fi
rm -f /usr/local/bin/campus-wifi-autologin /etc/NetworkManager/dispatcher.d/90-campus-wifi-autologin

if [ "${1:-}" = "--purge" ]; then
    rm -rf /etc/campus-wifi-autologin /var/lib/campus-wifi-autologin /var/log/campus-wifi-autologin
    echo "campus-wifi-autologin removed, including credentials and log."
else
    echo "campus-wifi-autologin removed. Credentials kept in /etc/campus-wifi-autologin (use --purge to delete)."
fi

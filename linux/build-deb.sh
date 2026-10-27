#!/usr/bin/env bash
#
# Build the .deb package:  ./build-deb.sh
# Output: ../dist/campus-wifi-autologin_<version>_all.deb  (not committed to git)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(sed -n 's/^readonly VERSION="\(.*\)"/\1/p' "$HERE/bin/campus-wifi-autologin")"
PKG=campus-wifi-autologin
OUT_DIR="$HERE/../dist"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
chmod 755 "$ROOT"

install -Dm755 "$HERE/bin/campus-wifi-autologin"                 "$ROOT/usr/bin/campus-wifi-autologin"
install -Dm644 "$HERE/systemd/campus-wifi-autologin.service"     "$ROOT/usr/lib/systemd/system/campus-wifi-autologin.service"
install -Dm644 "$HERE/systemd/campus-wifi-autologin.timer"       "$ROOT/usr/lib/systemd/system/campus-wifi-autologin.timer"
install -Dm755 "$HERE/networkmanager/90-campus-wifi-autologin"   "$ROOT/etc/NetworkManager/dispatcher.d/90-campus-wifi-autologin"

DOC="$ROOT/usr/share/doc/$PKG"
install -d "$DOC"
{
    echo "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
    echo "Upstream-Name: $PKG"
    echo "Source: https://github.com/Kenshin517/campus-wifi-autologin"
    echo
    echo "Files: *"
    echo "Copyright: 2026 Sandy Aprilando"
    echo "License: MIT"
    sed 's/^$/./; s/^/ /' "$HERE/../LICENSE"
} >"$DOC/copyright"
gzip -9n -c "$HERE/debian/changelog" >"$DOC/changelog.gz"
chmod 644 "$DOC"/*

install -d "$ROOT/DEBIAN"
for f in config postinst prerm postrm; do install -m755 "$HERE/debian/$f" "$ROOT/DEBIAN/$f"; done
install -m644 "$HERE/debian/templates" "$HERE/debian/conffiles" "$ROOT/DEBIAN/"
SIZE="$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)"
sed -e "s/@VERSION@/$VERSION/" -e "s/@SIZE@/$SIZE/" "$HERE/debian/control.in" >"$ROOT/DEBIAN/control"

mkdir -p "$OUT_DIR"
DEB="$OUT_DIR/${PKG}_${VERSION}_all.deb"
dpkg-deb --root-owner-group --build "$ROOT" "$DEB" >/dev/null
echo "Built $(cd "$OUT_DIR" && pwd)/$(basename "$DEB")"

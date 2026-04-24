#!/usr/bin/env bash
# restore.sh — Trackpad config'i default'a geri al.
#
# Kullanım:
#   sudo ./restore.sh                 # En yeni .bak.* dosyasından geri yükle
#   sudo ./restore.sh --orig          # Orijinal antiX default'una dön (.bak.orig)
#   sudo ./restore.sh --minimal       # Repo'daki minimal (pre-tuning) versiyona
#   sudo ./restore.sh /path/to/spec.bak   # Belirli bir backup dosyasından
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_MIN="$SCRIPT_DIR/../configs/30-touchpad-libinput.minimal.conf"
TARGET=/etc/X11/xorg.conf.d/30-touchpad-libinput.conf

if [ "$EUID" -ne 0 ]; then
    echo "HATA: root gerekir. Şöyle çalıştır:"
    echo "  sudo $0 $*"
    exit 1
fi

MODE="${1:-auto}"

case "$MODE" in
    --orig|orig)
        SRC="$TARGET.bak.orig"
        [ -f "$SRC" ] || { echo "HATA: $SRC yok (daha önce apply.sh çalışmamış olabilir)"; exit 1; }
        ;;
    --minimal|minimal)
        SRC="$REPO_MIN"
        [ -f "$SRC" ] || { echo "HATA: $SRC yok"; exit 1; }
        ;;
    auto)
        # En yeni .bak.* seç
        SRC=$(ls -1t "$TARGET".bak.* 2>/dev/null | head -1 || true)
        [ -n "$SRC" ] || { echo "HATA: Hiç backup bulunamadı. Seçenekler: --orig, --minimal"; exit 1; }
        ;;
    *)
        SRC="$MODE"
        [ -f "$SRC" ] || { echo "HATA: $SRC yok"; exit 1; }
        ;;
esac

echo "Restore: $SRC → $TARGET"
cp "$SRC" "$TARGET"
chmod 644 "$TARGET"

echo
echo "=== Yeni içerik ==="
cat "$TARGET"

cat <<'HINT'

Logout-login (veya reboot) sonrası aktif.
HINT

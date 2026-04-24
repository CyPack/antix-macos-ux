#!/usr/bin/env bash
# apply.sh — Kalıcı trackpad config yaz (/etc/X11/xorg.conf.d/).
# Sudo gerektirir.
#
# Kullanım:
#   sudo ./apply.sh 0.6
#   sudo ./apply.sh 0.6 flat       # AccelSpeed + flat profile
#   sudo ./apply.sh --from-repo    # repo'daki canonical dosyayı aynen kopyala
#
# Backup: /etc/X11/xorg.conf.d/30-touchpad-libinput.conf.bak.<YYYYMMDD>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CONF="$SCRIPT_DIR/../configs/30-touchpad-libinput.conf"
TARGET=/etc/X11/xorg.conf.d/30-touchpad-libinput.conf
TS=$(date +%Y%m%d)
BACKUP="$TARGET.bak.$TS"

if [ "$EUID" -ne 0 ]; then
    echo "HATA: root gerekir. Şöyle çalıştır:"
    echo "  sudo $0 $*"
    exit 1
fi

[ -d /etc/X11/xorg.conf.d ] || mkdir -p /etc/X11/xorg.conf.d

# Backup (varsa üzerine yazma)
if [ -f "$TARGET" ] && [ ! -f "$TARGET.bak.orig" ]; then
    cp "$TARGET" "$TARGET.bak.orig"
    echo "Orijinal backup: $TARGET.bak.orig"
fi
[ -f "$TARGET" ] && cp "$TARGET" "$BACKUP" && echo "Bugünkü backup:  $BACKUP"

# Mode 1: --from-repo (repo canonical)
if [ "${1:-}" = "--from-repo" ]; then
    [ -f "$REPO_CONF" ] || { echo "HATA: $REPO_CONF bulunamadı"; exit 1; }
    cp "$REPO_CONF" "$TARGET"
    chmod 644 "$TARGET"
    echo "Repo canonical config kuruldu: $TARGET"
    echo
    echo "=== Yeni içerik ==="
    cat "$TARGET"
    exit 0
fi

# Mode 2: değer + opsiyonel profile
VALUE="${1:-}"
PROFILE="${2:-adaptive}"

if [ -z "$VALUE" ]; then
    echo "Kullanım: sudo $0 <accel_speed> [adaptive|flat|custom]"
    echo "   veya: sudo $0 --from-repo"
    exit 1
fi

awk -v v="$VALUE" 'BEGIN {exit !(v >= -1 && v <= 1)}' || {
    echo "HATA: AccelSpeed [-1.0, 1.0] aralığında olmalı. Verilen: $VALUE"
    exit 1
}

case "$PROFILE" in
    adaptive|flat|custom) ;;
    *) echo "HATA: profile 'adaptive', 'flat' veya 'custom' olmalı. Verilen: $PROFILE"; exit 1 ;;
esac

cat > "$TARGET" <<CFG
# antiX Trackpad config — managed by CyPack/antix-macos-ux (trackpad/)
# Tuned $(date -Iseconds).
# Adjust AccelSpeed (-1.0 .. 1.0) to your preference; see trackpad/GUIDE.md.
Section "InputClass"
    Identifier          "touchpad"
    Driver              "libinput"
    MatchIsTouchpad     "on"
    Option "Tapping"              "on"
    Option "AccelSpeed"           "$VALUE"
    Option "AccelProfile"         "$PROFILE"
    Option "DisableWhileTyping"   "on"
    Option "NaturalScrolling"     "off"
    Option "HorizontalScrolling"  "on"
    Option "TappingButtonMap"     "lrm"
EndSection
CFG

chmod 644 "$TARGET"

echo "Kalıcı config yazıldı: $TARGET"
echo "AccelSpeed=$VALUE, AccelProfile=$PROFILE"
echo
echo "=== Yeni içerik ==="
cat "$TARGET"

cat <<'HINT'

Sonraki adım:
  - Logout-login (veya reboot) → X server yeni config'i yükler.
  - Session'da hemen görmek istersen:
      DISPLAY=:0 xinput set-prop "TouchPad" "libinput Accel Speed" <değer>

Geri almak için:
  sudo ./restore.sh
HINT

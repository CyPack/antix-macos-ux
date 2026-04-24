#!/usr/bin/env bash
# inspect.sh — trackpad/mouse tanı aracı
# Kullanım: ./inspect.sh [DEVICE_NAME_PATTERN]
# Örnek:    ./inspect.sh                    # tüm pointer cihazları
#           ./inspect.sh TouchPad           # sadece TouchPad ismindekini
#
# Driver tipi + property envanteri + config dosyası durumu raporlar.
set -euo pipefail

PATTERN="${1:-}"
: "${DISPLAY:=:0}"
export DISPLAY

echo "=== antiX Trackpad Inspector ==="
echo "DISPLAY=$DISPLAY"
echo "Session: ${XDG_SESSION_TYPE:-unknown}"
echo "Date: $(date -Iseconds)"
echo

echo "--- 1. Kernel + distro ---"
uname -rsm
[ -r /etc/os-release ] && . /etc/os-release && echo "Distro: $PRETTY_NAME"
echo

echo "--- 2. Input driver paketleri ---"
if command -v dpkg >/dev/null; then
    dpkg -l 2>/dev/null | awk '/xserver-xorg-input-(libinput|synaptics|evdev|wacom)|^ii.*libinput/ {print $2, $3}'
elif command -v rpm >/dev/null; then
    rpm -qa 2>/dev/null | grep -Ei "libinput|synaptics|xorg-x11-drv"
fi
echo

echo "--- 3. Pointer cihazları ---"
if ! command -v xinput >/dev/null; then
    echo "ERROR: xinput yüklü değil. Kur: sudo apt install xinput"
    exit 1
fi
xinput list --short 2>&1 | grep -Ei "pointer|touchpad|mouse" || xinput list
echo

echo "--- 4. Properties (pattern: ${PATTERN:-<all pointers>}) ---"
if [ -n "$PATTERN" ]; then
    DEVICES=$(xinput list --name-only | grep -i "$PATTERN" || true)
else
    # Master XTEST pointerleri hariç tut, slave pointer'ları al
    DEVICES=$(xinput list | awk -F'↳' '/slave  pointer/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); name=$2; sub(/[ \t]+id=.*/,"",name); print name}' | grep -vi "XTEST")
fi

if [ -z "$DEVICES" ]; then
    echo "(cihaz bulunamadı)"
    exit 0
fi

while IFS= read -r DEV; do
    [ -z "$DEV" ] && continue
    echo "### Device: $DEV"
    PROPS=$(xinput list-props "$DEV" 2>/dev/null || echo "")
    if [ -z "$PROPS" ]; then
        echo "  (property okunamadı)"; continue
    fi

    # Driver tespiti
    if echo "$PROPS" | grep -q "libinput "; then
        DRIVER="libinput"
    elif echo "$PROPS" | grep -q "Synaptics "; then
        DRIVER="synaptics"
    elif echo "$PROPS" | grep -q "Device Accel "; then
        DRIVER="evdev"
    elif echo "$PROPS" | grep -q "wacom "; then
        DRIVER="wacom"
    else
        DRIVER="unknown"
    fi
    echo "  Driver: $DRIVER"

    # Önemli property'leri highlight et
    case "$DRIVER" in
        libinput)
            echo "$PROPS" | grep -E "libinput (Accel (Speed|Profile)|Tapping|Natural Scrolling|Disable While Typing|Horizontal Scroll) (Enabled|Profile Enabled|Speed|Button Mapping) \(" | sed 's/^/    /'
            ;;
        synaptics)
            echo "$PROPS" | grep -E "Synaptics (Edge Scrolling|Two-Finger|Tap Time|Move Speed|Scrolling Distance) \(" | sed 's/^/    /'
            ;;
        evdev)
            echo "$PROPS" | grep -E "Device Accel " | sed 's/^/    /'
            ;;
    esac
    echo
done <<< "$DEVICES"

echo "--- 5. Xorg input config dosyaları ---"
for d in /etc/X11/xorg.conf.d /usr/share/X11/xorg.conf.d; do
    [ -d "$d" ] || continue
    echo "  $d/:"
    ls -la "$d" 2>/dev/null | awk 'NR>1 {print "    "$NF}' | grep -Ei "touchpad|libinput|synaptics|mouse|input" || echo "    (ilgili dosya yok)"
done
echo

echo "--- 6. Kalıcı trackpad config ---"
CONF=/etc/X11/xorg.conf.d/30-touchpad-libinput.conf
if [ -f "$CONF" ]; then
    echo "  $CONF ($(wc -c <"$CONF") byte)"
    sed 's/^/    /' "$CONF"
else
    echo "  $CONF YOK — trackpad default'ta çalışıyor"
fi

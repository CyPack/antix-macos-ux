#!/usr/bin/env bash
# test-speed.sh — geçici trackpad hız testi (session'da etkin, reboot'ta sıfırlanır).
#
# Kullanım:
#   ./test-speed.sh 0.6                        # default device "TouchPad" pattern
#   ./test-speed.sh 0.6 "Asus TouchPad"        # explicit device
#   ./test-speed.sh -0.3                       # yavaşlat
#   ./test-speed.sh 0.6 "Asus TouchPad" flat   # flat profile + hız
#
# Değer aralığı: -1.0 (en yavaş) ... 0.0 (default) ... 1.0 (en hızlı)
set -euo pipefail

VALUE="${1:-}"
DEVICE="${2:-TouchPad}"
PROFILE="${3:-}"   # opsiyonel: adaptive | flat | custom

if [ -z "$VALUE" ]; then
    echo "Kullanım: $0 <accel_speed> [device_pattern] [profile:adaptive|flat]"
    echo "Örnek:    $0 0.6 TouchPad adaptive"
    exit 1
fi

# Range sanity check
awk -v v="$VALUE" 'BEGIN {exit !(v >= -1 && v <= 1)}' || {
    echo "HATA: AccelSpeed [-1.0, 1.0] aralığında olmalı. Verilen: $VALUE"
    exit 1
}

: "${DISPLAY:=:0}"
export DISPLAY

# Cihazı bul
MATCHED=$(xinput list --name-only | grep -i "$DEVICE" | head -1 || true)
if [ -z "$MATCHED" ]; then
    echo "HATA: '$DEVICE' pattern'iyle cihaz bulunamadı."
    echo "Mevcut pointer cihazları:"
    xinput list | awk -F'↳' '/slave  pointer/ {print "  " $2}'
    exit 1
fi

echo "Device: $MATCHED"
echo "Accel Speed: $VALUE"

# Uygula
xinput set-prop "$MATCHED" "libinput Accel Speed" "$VALUE"

# Opsiyonel profile
if [ -n "$PROFILE" ]; then
    case "$PROFILE" in
        adaptive) xinput set-prop "$MATCHED" "libinput Accel Profile Enabled" 1 0 0; echo "Profile: adaptive" ;;
        flat)     xinput set-prop "$MATCHED" "libinput Accel Profile Enabled" 0 1 0; echo "Profile: flat (1:1, ivmesiz)" ;;
        custom)   xinput set-prop "$MATCHED" "libinput Accel Profile Enabled" 0 0 1; echo "Profile: custom" ;;
        *) echo "UYARI: bilinmeyen profile '$PROFILE' — adaptive|flat|custom" ;;
    esac
fi

# Doğrula
echo
echo "=== Aktif değerler ==="
xinput list-props "$MATCHED" | grep -E "libinput (Accel Speed|Accel Profile Enabled) \(" | grep -v Default

cat <<'HINT'

Şimdi trackpad'i dene:
  1. Diagonal test: köşeden ortaya + ortadan karşı köşeye sweep
  2. Precision test: birbirine yakın iki UI öğesi arasında geç
  3. 1-2 dakika normal iş yap

Memnunsan kalıcı yap:
  sudo ./scripts/apply.sh <değer>

Beğenmedinse tekrar dene:
  ./test-speed.sh <yeni-değer>

Reset (default 0):
  ./test-speed.sh 0
HINT

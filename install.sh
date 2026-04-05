#!/bin/sh
# antiX macOS-style UX installer
# Restores FULL setup from backup state to current customized state
#
# Usage (from Fedora, after backup restore + reboot):
#   sshpass -p 'asus' ssh asus@192.168.2.17 'sudo apt-get install -y git && git clone https://github.com/CyPack/antix-macos-ux /tmp/antix-macos-ux && echo "asus" | sudo -S sh /tmp/antix-macos-ux/install.sh'
#
# Or locally on antiX:
#   sudo sh install.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="/home/asus"
USERNAME="asus"

echo "================================================"
echo "  antiX macOS-style UX Installer"
echo "  Target: antiX-26 + IceWM + Atom x5-Z8350"
echo "================================================"
echo ""

# --- Step 1: zram lz4 runit service ---
echo "=== 1/5. zram lz4 900MB (runit service) ==="
mkdir -p /etc/sv/zram
cp "$SCRIPT_DIR/configs/zram-run" /etc/sv/zram/run
chmod 755 /etc/sv/zram/run
ln -sf /etc/sv/zram /etc/runit/runsvdir/default/
echo 'vm.swappiness=60' > /etc/sysctl.d/99-zram.conf
# Activate immediately (don't wait for reboot)
sh /etc/sv/zram/run 2>/dev/null || true
echo "[OK] zram lz4 active"

# --- Step 2: Install packages ---
echo "=== 2/5. Install tint2 + tools ==="
apt-get update -qq
apt-get install -y -qq tint2 wmctrl xdotool 2>/dev/null || apt-get install -y tint2
echo "[OK] Packages installed"

# --- Step 3: tint2 dock config ---
echo "=== 3/5. tint2 macOS dock ==="
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.config/tint2"
cp "$SCRIPT_DIR/configs/tint2-dock.conf" "$USER_HOME/.config/tint2/tint2-dock.conf"
chown "$USERNAME:$USERNAME" "$USER_HOME/.config/tint2/tint2-dock.conf"
echo "[OK] tint2 config installed"

# --- Step 4: IceWM config ---
echo "=== 4/5. IceWM config (taskbar top + dock startup) ==="
# Backup originals
cp "$USER_HOME/.icewm/prefoverride" "$USER_HOME/.icewm/prefoverride.bak" 2>/dev/null || true
cp "$USER_HOME/.icewm/startup" "$USER_HOME/.icewm/startup.bak" 2>/dev/null || true
# Install new
cp "$SCRIPT_DIR/configs/icewm-prefoverride" "$USER_HOME/.icewm/prefoverride"
cp "$SCRIPT_DIR/configs/icewm-startup" "$USER_HOME/.icewm/startup"
chmod +x "$USER_HOME/.icewm/startup"
chown "$USERNAME:$USERNAME" "$USER_HOME/.icewm/prefoverride" "$USER_HOME/.icewm/startup"
# IMPORTANT: do NOT add doNotCover to winoptions (causes window resize bug)
sed -i '/tint2.*doNotCover/d' "$USER_HOME/.icewm/winoptions" 2>/dev/null || true
echo "[OK] IceWM config installed"

# --- Step 5: Desktop shortcuts ---
echo "=== 5/5. Desktop shortcuts ==="
sudo -u "$USERNAME" cp /usr/share/applications/firefox-esr.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/libreoffice-writer.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/libreoffice-calc.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/libreoffice-impress.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/libreoffice-draw.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/leafpad.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" cp /usr/share/applications/roxterm.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
sudo -u "$USERNAME" mkdir -p "$USER_HOME/Desktop/Applications"
sudo -u "$USERNAME" cp /usr/share/applications/*.desktop "$USER_HOME/Desktop/Applications/" 2>/dev/null || true
echo "[OK] Desktop shortcuts installed"

echo ""
echo "================================================"
echo "  INSTALLATION COMPLETE"
echo "================================================"
echo ""
echo "  zram:      $(cat /proc/swaps | grep zram > /dev/null && echo 'ACTIVE' || echo 'Will activate on reboot')"
echo "  tint2:     Config ready at ~/.config/tint2/tint2-dock.conf"
echo "  IceWM:     Taskbar at top, dock in startup"
echo "  Shortcuts: Firefox, LibreOffice, Leafpad, Terminal + All Apps folder"
echo ""
echo "  NEXT STEPS:"
echo "  1. Reboot: sudo reboot"
echo "  2. After reboot: zram active + tint2 dock auto-starts"
echo "  3. If dock doesn't appear: right-click desktop > Logout > Restart IceWM"
echo ""
echo "  KNOWN LIMITATIONS (see docs/TRADEOFF-ANALYSIS.md):"
echo "  - Dock icons always launch new instance (tint2 design limitation)"
echo "  - Dock background opaque (pseudo-transparency vs dark wallpaper)"
echo "  - Use Alt+Tab or top taskbar to switch between windows"
echo ""

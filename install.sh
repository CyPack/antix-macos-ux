#!/bin/sh
# antiX macOS-style UX installer
# Run on antiX as root: sudo sh install.sh
# Or from remote: sshpass -p 'asus' ssh asus@192.168.2.17 'cd /tmp/antix-macos-ux && echo "asus" | sudo -S sh install.sh'

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME="/home/asus"

echo "=== 1. zram lz4 runit service ==="
mkdir -p /etc/sv/zram
cp "$SCRIPT_DIR/configs/zram-run" /etc/sv/zram/run
chmod 755 /etc/sv/zram/run
ln -sf /etc/sv/zram /etc/runit/runsvdir/default/
echo 'vm.swappiness=60' > /etc/sysctl.d/99-zram.conf
echo "zram service installed"

echo "=== 2. tint2 dock ==="
apt-get update -qq && apt-get install -y -qq tint2 wmctrl xdotool 2>/dev/null
sudo -u asus mkdir -p "$USER_HOME/.config/tint2"
cp "$SCRIPT_DIR/configs/tint2-dock.conf" "$USER_HOME/.config/tint2/tint2-dock.conf"
chown asus:asus "$USER_HOME/.config/tint2/tint2-dock.conf"
echo "tint2 config installed"

echo "=== 3. IceWM config ==="
cp "$SCRIPT_DIR/configs/icewm-prefoverride" "$USER_HOME/.icewm/prefoverride"
cp "$SCRIPT_DIR/configs/icewm-startup" "$USER_HOME/.icewm/startup"
chown asus:asus "$USER_HOME/.icewm/prefoverride" "$USER_HOME/.icewm/startup"
echo "IceWM config installed"

echo "=== 4. Desktop shortcuts ==="
sudo -u asus cp /usr/share/applications/firefox-esr.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/libreoffice-writer.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/libreoffice-calc.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/libreoffice-impress.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/libreoffice-draw.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/leafpad.desktop "$USER_HOME/Desktop/"
sudo -u asus cp /usr/share/applications/roxterm.desktop "$USER_HOME/Desktop/"
sudo -u asus mkdir -p "$USER_HOME/Desktop/Applications"
sudo -u asus cp /usr/share/applications/*.desktop "$USER_HOME/Desktop/Applications/" 2>/dev/null
echo "Desktop shortcuts installed"

echo ""
echo "=== DONE ==="
echo "Reboot to activate zram. Restart IceWM for dock + taskbar changes."
echo "tint2 starts automatically via ~/.icewm/startup"

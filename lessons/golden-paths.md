# antiX Customization — Golden Paths (Proven Workflows)

## GP-1: zram lz4 on antiX-26 (runit)

| Step | Command | Notes |
|------|---------|-------|
| 1. Create service dir | `sudo mkdir -p /etc/sv/zram` | |
| 2. Write run script | See template below | Must include PATH, wait loop, sv pause |
| 3. Make executable | `sudo chmod 755 /etc/sv/zram/run` | |
| 4. Enable service | `sudo ln -sf /etc/sv/zram /etc/runit/runsvdir/default/` | Symlink to default runlevel |
| 5. Persist swappiness | `echo 'vm.swappiness=60' \| sudo tee /etc/sysctl.d/99-zram.conf` | |
| 6. Reboot test | `reboot` then `cat /proc/swaps` | MUST verify after reboot |

**Run script template (`/etc/sv/zram/run`):**
```sh
#!/bin/sh
PATH=/sbin:/usr/sbin:/bin:/usr/bin
export PATH
if grep -q zram /proc/swaps 2>/dev/null; then
    echo "zram already active"
else
    if modprobe zram; then
        for i in 1 2 3 4 5; do [ -e /dev/zram0 ] && break; sleep 1; done
        if [ -e /dev/zram0 ]; then
            echo lz4 > /sys/block/zram0/comp_algorithm
            echo 943718400 > /sys/block/zram0/disksize
            mkswap --label ZRAM_SWAP /dev/zram0
            swapon --priority 100 /dev/zram0
            sysctl vm.swappiness=60
            echo "zram lz4 900MB active"
        else echo "ERROR: /dev/zram0 not found"; fi
    else echo "ERROR: modprobe zram failed"; fi
fi
exec sv pause "$(dirname "$(readlink -f "$0")")"
```

**Pre-conditions:** antiX-26 with runit, kernel 6.6+ (lz4 module built-in)
**Sizing:** 50% of RAM for <=2GB systems. lz4 ONLY on Atom/Celeron (no zstd).

---

## GP-2: tint2 macOS-style Dock with Autohide on IceWM

| Step | Command/Action | Notes |
|------|----------------|-------|
| 1. Install tint2 | `sudo apt-get update && sudo apt-get install -y tint2` | May need apt update first |
| 2. Create config | `~/.config/tint2/tint2-dock.conf` | See template below |
| 3. IceWM prefoverride | Add `TaskBarAtTop=1`, edge switch disabled | Taskbar to top, no edge conflicts |
| 4. DO NOT add doNotCover | Never add `tint2.Tint2.doNotCover: 1` to winoptions | This causes window resize bug |
| 5. Add to startup | `~/.icewm/startup`: `sleep 2 && G_SLICE=always-malloc tint2 -c ~/.config/tint2/tint2-dock.conf &` | G_SLICE prevents segfault |
| 6. Restart IceWM | Right-click → Logout → Restart IceWM | |
| 7. Test autohide | Mouse to bottom edge | Should appear instantly |

**Critical tint2 config values:**
```ini
panel_position = bottom center horizontal
panel_layer = top          # MUST be top — prevents windows from covering trigger
panel_size = 50% 48
panel_shrink = 1           # Shrink to icon width, center
panel_dock = 0             # Avoid WMHints confusion with IceWM
wm_menu = 0                # Don't forward events to IceWM
strut_policy = none         # CRITICAL — no space reservation, dock overlays windows
autohide = 1
autohide_show_timeout = 0.0 # Instant show — nonzero feels broken
autohide_hide_timeout = 0.5
autohide_height = 2         # 2px trigger strip
```

**IceWM prefoverride (`~/.icewm/prefoverride`):**
```ini
TaskBarAtTop=1
VerticalEdgeSwitch=0
HorizontalEdgeSwitch=0
EdgeSwitch=0
```

**Pre-conditions:** antiX-26, IceWM, tint2 17.x
**Known issue:** tint2 17.0.1 segfaults with `strut_policy = none` without `G_SLICE=always-malloc`

---

## GP-3: Full eMMC Backup over SSH (dd + zstd)

| Step | Command | Notes |
|------|---------|-------|
| 1. Create backup dir on remote | `mkdir -p ~/backups/antix-asus` | On Fedora/host machine |
| 2. Sync filesystem | `ssh antix 'sudo sync && sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"'` | Flush writes |
| 3. dd + zstd over SSH | `ssh antix 'sudo dd if=/dev/mmcblk0 bs=4M status=progress' \| zstd -3 -T4 -o ~/backups/antix-asus/backup.img.zst` | ~26 min for 29GB eMMC → 2.54GB compressed |
| 4. Verify | `ls -lh ~/backups/antix-asus/backup.img.zst` | Should be 2-3GB |

**Restore (if system breaks):**
```bash
# If SSH works:
zstd -d backup.img.zst -c | ssh antix 'sudo dd of=/dev/mmcblk0 bs=4M'
# If SSH broken: boot antiX Live USB, mount network, dd back
```

**Pre-conditions:** sshpass + ssh access, zstd on host machine

---

## GP-4: Desktop Application Shortcuts on antiX (ZzzFM)

| Step | Command | Notes |
|------|---------|-------|
| 1. Copy .desktop files | `cp /usr/share/applications/app.desktop ~/Desktop/` | ZzzFM auto-detects |
| 2. Application folder | `mkdir ~/Desktop/Applications && cp /usr/share/applications/*.desktop ~/Desktop/Applications/` | All 194 apps in one folder |
| 3. No restart needed | ZzzFM refreshes automatically | |

**Pre-conditions:** zzz-icewm session (default antiX-26)

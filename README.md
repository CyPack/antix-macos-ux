# antiX Linux — macOS-style UX on Low-End Hardware

Transform antiX-26 (Debian Trixie) into a macOS-like desktop on ultra-low-end hardware. Tested on Intel Atom x5-Z8350 with 1.8GB RAM and 29GB eMMC.

## What This Repo Contains

Real-world, battle-tested configurations and lessons learned from setting up a macOS-style desktop on antiX Linux. Every fix was discovered through actual debugging — not copied from generic guides.

### Hardware Target
| Spec | Value |
|------|-------|
| CPU | Intel Atom x5-Z8350 @ 1.44GHz (4 core, NO AVX2) |
| RAM | 1.8GB |
| Storage | 29GB eMMC (ext4) |
| OS | antiX-26 (Debian Trixie), runit init |
| WM | IceWM + ZzzFM desktop |

### What's Included

| Component | Description | RAM Cost |
|-----------|-------------|----------|
| **zram lz4** | Compressed swap in RAM — runit service, reboot-safe | ~0 (kernel) |
| **tint2 dock** | macOS-style bottom dock with autohide | ~24MB |
| **IceWM config** | Taskbar at top (menu bar style), edge switch disabled | 0 |
| **Backup strategy** | Full eMMC dd image over SSH with zstd compression | N/A |

## Quick Start

### 1. zram lz4 (swap for low-RAM systems)

```bash
# Create runit service
sudo mkdir -p /etc/sv/zram
sudo cp configs/zram-run /etc/sv/zram/run
sudo chmod 755 /etc/sv/zram/run
sudo ln -sf /etc/sv/zram /etc/runit/runsvdir/default/

# Persist swappiness
echo 'vm.swappiness=60' | sudo tee /etc/sysctl.d/99-zram.conf

# Reboot and verify
reboot
cat /proc/swaps  # Should show /dev/zram0
```

### 2. tint2 macOS Dock

```bash
# Install
sudo apt-get update && sudo apt-get install -y tint2

# Copy config
mkdir -p ~/.config/tint2
cp configs/tint2-dock.conf ~/.config/tint2/tint2-dock.conf

# Copy IceWM overrides
cp configs/icewm-prefoverride ~/.icewm/prefoverride

# Add to startup
echo '
# macOS-style dock
sleep 2 && G_SLICE=always-malloc tint2 -c ~/.config/tint2/tint2-dock.conf &' >> ~/.icewm/startup

# Restart IceWM (right-click desktop → Logout → Restart IceWM)
```

### 3. Desktop Shortcuts

```bash
# Individual apps
cp /usr/share/applications/firefox-esr.desktop ~/Desktop/
cp /usr/share/applications/libreoffice-writer.desktop ~/Desktop/
cp /usr/share/applications/leafpad.desktop ~/Desktop/
cp /usr/share/applications/roxterm.desktop ~/Desktop/

# All apps in a folder
mkdir -p ~/Desktop/Applications
cp /usr/share/applications/*.desktop ~/Desktop/Applications/
```

### 4. Full System Backup (eMMC over SSH)

```bash
# From your host machine:
ssh antix 'sudo sync && sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"'
ssh antix 'sudo dd if=/dev/mmcblk0 bs=4M status=progress' | zstd -3 -T4 -o backup.img.zst
# 29GB → ~2.5GB compressed, ~26 minutes

# Restore:
zstd -d backup.img.zst -c | ssh antix 'sudo dd of=/dev/mmcblk0 bs=4M'
```

## Key Lessons Learned

### Why lz4, NOT zstd for zram on Atom CPUs

| Algorithm | Speed (MB/s) | Ratio | CPU on Atom |
|-----------|-------------|-------|-------------|
| **lz4** | 7943 | 2.63x | Negligible |
| zstd | 2612 | 3.37x | **3-5x slower (no AVX2!)** |

Atom x5-Z8350 has SSE4.2 but NO AVX2. zstd's best optimizations require AVX2. The 28% better compression ratio is NOT worth the 3-5x CPU penalty on this weak CPU.

### Why runit service, NOT rc.local

antiX-26 with runit does NOT run `/etc/rc.local`. The `rc-local` runit service runs `/etc/runit/rc.local`, but with `set -e` — any command failure silently kills the entire script. A dedicated `/etc/sv/zram/` service is the idiomatic runit approach.

### The tint2 autohide + IceWM Triple Bug

Three things must be correct simultaneously for autohide to work without window resize:

1. **`strut_policy = none`** in tint2 — otherwise IceWM reserves space for the dock
2. **`G_SLICE=always-malloc`** env var — tint2 17.0.1 segfaults with `strut_policy = none` without this
3. **NEVER add `doNotCover: 1`** to `~/.icewm/winoptions` — this tells IceWM to resize windows to avoid covering the dock, which is exactly what we DON'T want

### tint2 autohide is event-based, NOT polling

tint2 uses X11 `EnterNotify`/`LeaveNotify` events — **zero CPU overhead** when the dock is hidden. The concern about autohide consuming CPU on weak hardware is unfounded.

## Resource Usage

| Component | RAM (RSS) | CPU (idle) | Notes |
|-----------|-----------|-----------|-------|
| tint2 dock | 24 MB | 0.2% | Event-based autohide = 0 CPU when hidden |
| IceWM | ~10 MB | 0.2% | |
| Conky | ~6 MB | ~1% | Pre-installed in antiX |
| zram overhead | ~1-2 MB | 0% | Kernel module, negligible |
| **Total added** | **~24 MB** | **~0.2%** | |

For comparison: Firefox with 3 tabs uses ~700MB RAM and 30%+ CPU on this hardware.

## Files

```
configs/
├── zram-run                 # /etc/sv/zram/run — runit service script
├── tint2-dock.conf          # ~/.config/tint2/tint2-dock.conf — macOS dock
├── icewm-prefoverride       # ~/.icewm/prefoverride — taskbar top + edge switch off
└── icewm-startup            # ~/.icewm/startup snippet — dock autostart

lessons/
├── errors.md                # 7 known errors with fixes
├── golden-paths.md          # 4 proven step-by-step workflows
└── edge-cases.md            # 10 edge cases and gotchas
```

## Forum References

- [Make antiX 23 look almost like macOS](https://www.antixforum.com/forums/topic/how-to-make-antix-23-look-almost-like-macos/) — IceWM + tint2 dock guide
- [tint2 Windows 10 style customization](https://www.antixforum.com/forums/topic/how-to-add-feature-to-antix-and-also-more-window-10-like-with-tint2/) — 82 replies, 5 pages
- [antiX zram-zswap Manager](https://www.antixforum.com/forums/topic/antix-zram-zswap-manager/) — Community GUI tool
- [IceWM strut handling issue #290](https://github.com/bbidulock/icewm/issues/290) — Why doNotCover causes resize
- [tint2 autohide mechanism](https://github.com/o9000/tint2/blob/master/doc/tint2.md) — X11 event-based, not polling
- [Zram Performance Analysis](https://notes.xeome.dev/notes/Zram) — lz4 vs zstd benchmarks

## License

MIT — Use freely. If this helps you, consider sharing your setup on the [antiX Forum](https://www.antixforum.com/).

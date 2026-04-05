# Technical Limitations, Root Causes & Future Watch

> Everything we tried, why it failed, and what to check when upstream updates.
> Last updated: 2026-04-05

---

## 1. Dock Relaunch Problem (UNSOLVED)

### Symptom
Clicking a dock icon when the app is already running opens a NEW instance instead of focusing the existing window.

### Root Cause
tint2's Launcher (`L`) panel item is a **pure launcher** — it executes the `Exec=` line from the `.desktop` file every time, with no awareness of running windows. This is by design, not a bug. Feature request [tint2 Issue #356](https://github.com/sabit/tint2/issues/356) was filed in **2011** and **never implemented**. tint2 is now frozen at 17.0.2 (final release, no more development).

### What We Tried

| Approach | Result | Why It Failed |
|----------|--------|---------------|
| Button (`P`) + wmctrl wrapper script | Works for single-class apps | **LibreOffice blocker**: Writer, Calc, Impress all share WM_CLASS `libreoffice`. Clicking Calc icon focuses Writer instead. No reliable way to distinguish them. |
| `panel_items = LT` (Launcher + Taskbar) | Partially works | Two separate areas — launcher icons on left (always relaunch), taskbar on right (click = focus). Not a unified dock. Duplicated icons. |
| `rof` (Run Or Focus) script | Unreliable | Matches by window title, not WM_CLASS. Firefox changes title per tab — matching breaks constantly. |
| `jumpapp` | Not tested (requires build from source) | Not in antiX repos. Needs `build-essential debhelper pandoc shunit2`. Overkill for a netbook. |
| Plank dock (native macOS behavior) | Known bug on IceWM | Click-through area bug with compositor — hidden dock blocks mouse clicks on the area it occupied. JWM doesn't have this bug but switching WM is too invasive. |

### The LibreOffice WM_CLASS Problem (Detail)

```bash
$ xprop WM_CLASS  # click on Writer window
WM_CLASS(STRING) = "libreoffice", "libreoffice-writer"

$ xprop WM_CLASS  # click on Calc window  
WM_CLASS(STRING) = "libreoffice", "libreoffice-calc"
```

Actually, LibreOffice **does** have distinct WM_CLASS instances (`libreoffice-writer`, `libreoffice-calc`). The wrapper script used `grep -i "$WM_CLASS"` which matched the shared `libreoffice` prefix. A more precise match on the full class string (`libreoffice-writer`) would work.

**This means the Button approach IS viable** — but was abandoned due to:
1. Config complexity (7 lines per app × 9 apps = 63 lines)
2. Maintenance burden (need to discover WM_CLASS for each new app)
3. Risk of silent breakage if WM_CLASS changes in an update

### Future Watch
- [ ] **tint2 fork**: If someone forks tint2 and adds dock mode (unified launcher+taskbar), switch to it
- [ ] **nwg-dock**: [nwg-piotr/nwg-dock](https://github.com/nwg-piotr/nwg-dock) — GTK3 dock with run-or-raise. Currently Wayland-only but X11 support possible
- [ ] **Plank Reloaded**: [nicfit/plank-reloaded](https://github.com/nicfit/plank-reloaded) — active fork. If IceWM click-through bug gets fixed, Plank is the best option
- [ ] **IceWM native dock**: IceWM is actively maintained ([bbidulock/icewm](https://github.com/bbidulock/icewm)). If they add dock-style taskbar, it would be zero-dependency

### Workaround (Current)
Users switch windows via:
- IceWM taskbar at top (shows all open windows, click = focus)
- `Alt+Tab` keyboard shortcut
- Dock icons always launch — acceptable for light desktop use

---

## 2. Transparent Dock Background (UNSOLVED)

### Symptom
Dock background remains dark/opaque despite setting `background_color = #000000 0` (alpha = 0) and `panel_background_id = 0`.

### Root Cause (Most Likely)
**The pseudo-transparency IS working** — but the wallpaper is dark ("Solid-architecture.jpg"). Pseudo-transparency paints the wallpaper region behind the panel as the panel's background. Dark wallpaper region = dark panel = looks identical to opaque.

We did NOT conclusively prove this because the bright wallpaper test (`feh --bg-fill antiX-blue.jpg`) also showed no change. This could mean:
1. The bright wallpaper didn't cover the bottom-center area, OR
2. Pseudo-transparency is genuinely broken on tint2 17.0.1 + Debian Trixie

### What We Tried

| Approach | Result | Why It Failed |
|----------|--------|---------------|
| `background_color = #000000 0` (alpha 0) | No visible change | Known `#000000` bug — tint2 may ignore alpha on pure black. Should use `#010101 0` instead. **Not tested with this workaround.** |
| `panel_background_id = 0` (built-in transparent) | No visible change | May require `disable_transparency = 1` to activate pseudo-transparency mode |
| `disable_transparency = 1` | No visible change | Added late — may need combined with `panel_background_id = 0` AND feh ordering |
| `disable_transparency = 1` + `panel_background_id = 0` + feh first | No visible change | Wallpaper still dark? Or genuine tint2 17.0.1 bug? |
| Change wallpaper to bright color | No visible change | Inconclusive — may not have covered dock area, or pseudo-transparency genuinely broken |
| xcompmgr (real compositor) | **Not tested** | Available (`/usr/bin/xcompmgr`, ~1MB RAM) but avoided due to stability concerns on Atom |

### The `#000000` Bug (NOT TESTED)
[Arch Forums report](https://bbs.archlinux.org/viewtopic.php?id=244306): using `#000000` as background_color causes tint2 to ignore alpha values entirely. Fix: use `#010101 0` instead. **We never tested this workaround.**

### Technical Details

```
# Root pixmap IS set (feh works correctly):
_XROOTPMAP_ID(PIXMAP): pixmap id # 0x1400001
ESETROOT_PMAP_ID(PIXMAP): pixmap id # 0x1400001

# No compositor running
# tint2 17.0.1 (frozen upstream at 17.0.2)
# G_SLICE=always-malloc required for strut_policy=none
```

### Future Watch
- [ ] **Test `#010101 0`**: Simple fix — change background_color from `#000000 0` to `#010101 0`
- [ ] **Test with solid red wallpaper**: `hsetroot -solid "#FF0000"` (hsetroot not installed, needs `apt install hsetroot`)
- [ ] **xcompmgr test**: `xcompmgr -c -C -n &` — 1MB RAM, lightest compositor. antiX Control Centre supports it ("visual effects"). Worth 5 minutes of testing
- [ ] **picom xrender**: `picom --backend xrender` — if xcompmgr is unstable. Atom CPU can handle xrender (NOT glx)
- [ ] **tint2 replacement**: If a GTK3/4 panel with native transparency support becomes available for IceWM

---

## 3. Bugs We Fixed (Reference)

### 3a. tint2 17.0.1 Segfault with `strut_policy = none`
- **Root cause**: glib slice allocator bug in tint2 17.0.1 on Debian Trixie
- **Fix**: `G_SLICE=always-malloc` environment variable before launching tint2
- **Source**: tint2 itself prints this hint in its startup message

### 3b. Dock Autohide Causes Window Resize
- **Root cause**: `doNotCover: 1` in `~/.icewm/winoptions` tells IceWM to resize windows to avoid covering the dock panel. Combined with autohide, windows resize on every show/hide cycle.
- **Fix**: Remove `tint2.Tint2.doNotCover` from winoptions + set `strut_policy = none` in tint2 config
- **Isolation method**: Added doNotCover back → resize returned. Removed → fixed. Confirmed.
- **Source**: [IceWM Issue #290](https://github.com/bbidulock/icewm/issues/290)

### 3c. Dock Autohide Unreliable (Mouse Hover Not Detected)
- **Root cause (multi-factor)**:
  1. `panel_layer != top` → maximized windows cover the 2px trigger strip
  2. `autohide_show_timeout > 0` → perceived as broken (delay before appearing)
  3. IceWM edge switching steals bottom-edge mouse events
- **Fix**: `panel_layer = top`, `autohide_show_timeout = 0.0`, `VerticalEdgeSwitch=0`, `HorizontalEdgeSwitch=0`, `EdgeSwitch=0`, `panel_dock = 0`, `wm_menu = 0`
- **Source**: [tint2 docs](https://github.com/o9000/tint2/blob/master/doc/tint2.md), [FreeBSD Forums](https://forums.freebsd.org/threads/openbox-tint2-hiding-un-hiding-problems.101004/)

### 3d. Dock Shows Black Square After Adding NoDisplay App
- **Root cause**: `icewm-manager-gui.desktop` has `NoDisplay=true`. tint2 fails to render it and corrupts the entire launcher panel.
- **Fix**: Never add `.desktop` files with `NoDisplay=true`. Check with `grep NoDisplay` before adding.
- **Prevention**: `grep -l NoDisplay=true /usr/share/applications/*.desktop` to list all hidden apps

### 3e. zram Not Starting After Reboot
- **Root cause**: antiX-26 runit does NOT run `/etc/rc.local`. The `rc-local` service runs `/etc/runit/rc.local` but under `set -e` — any command failure silently kills the script. Also, `$PATH` doesn't include `/sbin:/usr/sbin` during early boot.
- **Fix**: Dedicated runit service at `/etc/sv/zram/run` with explicit PATH, wait loop for `/dev/zram0`, and `exec sv pause` at end
- **Source**: [antiX Forum](https://www.antixforum.com/forums/topic/antix-22-runit-and-rc-local/), [Dev1 Galaxy runit guide](https://dev1galaxy.org/viewtopic.php?pid=62060)

### 3f. Dock Left-Aligned Instead of Centered
- **Root cause**: `panel_size = 0 48` means full-width panel, icons start at left edge
- **Fix**: `panel_size = 50% 48` + `panel_shrink = 1` — shrinks to icon width and centers

---

## 4. Hardware Constraints (Permanent)

These are not bugs — they are hardware limitations that will never change:

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| Atom x5-Z8350 has NO AVX2 | zstd compression 3-5x slower than on modern CPUs | Use lz4 for zram (2.63x ratio, negligible CPU) |
| 1.8GB RAM | Firefox with 5+ tabs = OOM risk | zram lz4 900MB provides safety net (~2.7GB effective) |
| 29GB eMMC (not SSD) | Random 4K read 25-50x slower than SSD | zram preferred over eMMC swap |
| No GPU acceleration for compositing | picom GLX backend = 100% CPU | xrender backend only, or no compositor |
| tint2 17.0.1 frozen upstream | Bugs will never be fixed | G_SLICE workaround, avoid strut_policy=none without it |

---

## 5. Version Matrix (For Future Checks)

| Component | Current Version | Check Command | What to Watch |
|-----------|----------------|---------------|---------------|
| antiX | 26 (Debian Trixie) | `cat /etc/antix-version` | antiX 27 may change init default |
| tint2 | 17.0.1 | `tint2 -v` | Frozen upstream — only Debian patches |
| IceWM | 3.x | `icewm --version` | Active development — dock features possible |
| Kernel | 6.6.119 | `uname -r` | zram module built-in since 3.14 |
| glib2 | 2.x (Trixie) | `dpkg -l libglib2.0-0t64` | G_SLICE workaround may become unnecessary |
| wmctrl | 1.07 | `wmctrl --version` | Stable, no changes expected |
| xdotool | 3.20160805 | `dpkg -l xdotool` | Stable |
| Plank | Available in repos | `apt-cache show plank` | Check if IceWM click-through bug is fixed |

---

## 6. Quick Reference: All Forum/Issue Links

### antiX Forum
- [Make antiX 23 look almost like macOS](https://www.antixforum.com/forums/topic/how-to-make-antix-23-look-almost-like-macos/) — IceWM + tint2 dock (Plank bug documented here)
- [Make antiX look like macOS](https://www.antixforum.com/forums/topic/make-antix-look-like-macos/) — Original macOS guide, Plank click-through issue
- [Make antiX look like macOS with JWM](https://www.antixforum.com/forums/topic/how-to-make-antix-look-like-macos-with-jwm/) — JWM avoids Plank bug
- [tint2 Windows 10 style](https://www.antixforum.com/forums/topic/how-to-add-feature-to-antix-and-also-more-window-10-like-with-tint2/) — 82 replies, PPC's comprehensive guide
- [antiX zram-zswap Manager](https://www.antixforum.com/forums/topic/antix-zram-zswap-manager/) — Community GUI tool
- [antiX runit and rc.local](https://www.antixforum.com/forums/topic/antix-22-runit-and-rc-local/) — Why rc.local doesn't work on runit
- [Best modern looking antiX desktop](https://www.antixforum.com/forums/topic/who-has-the-best-modern-looking-antix-desktop-show-us-a-pic/) — Screenshot gallery
- [zram to improve performance](https://www.antixforum.com/forums/topic/swap-zram-to-improve-performance/) — Community experience reports

### GitHub/GitLab Issues
- [tint2 #356 — Dock mode request (2011, never implemented)](https://github.com/sabit/tint2/issues/356)
- [IceWM #290 — Panel strut/doNotCover behavior](https://github.com/bbidulock/icewm/issues/290)
- [picom #145 — 100% CPU on Atom (GLX backend)](https://github.com/yshui/picom/issues/145)

### Tools & Alternatives
- [nwg-piotr/rof — Run Or Focus script](https://github.com/nwg-piotr/rof)
- [mkropat/jumpapp — Run-or-raise switcher](https://github.com/mkropat/jumpapp)
- [ice-be/tint2-clear — Transparent tint2 config example](https://github.com/ice-be/tint2-clear)
- [nicfit/plank-reloaded — Active Plank fork](https://github.com/nicfit/plank-reloaded)
- [nwg-piotr/nwg-dock — GTK dock (Wayland, X11 TBD)](https://github.com/nwg-piotr/nwg-dock)
- [tint2 official docs](https://github.com/o9000/tint2/blob/master/doc/tint2.md)

### Research Sources
- [Zram Performance Analysis (lz4 vs zstd benchmarks)](https://notes.xeome.dev/notes/Zram)
- [In Defence of Swap — Chris Down (Facebook kernel engineer)](https://chrisdown.name/2018/01/02/in-defence-of-swap.html)
- [Arch Forums — tint2 #000000 transparency bug](https://bbs.archlinux.org/viewtopic.php?id=244306)
- [Arch Forums — tint2 transparency race condition](https://bbs.archlinux.org/viewtopic.php?id=191562)
- [FreeBSD Forums — tint2 autohide fix](https://forums.freebsd.org/threads/openbox-tint2-hiding-un-hiding-problems.101004/)
- [Dev1 Galaxy — runit guide for Debian](https://dev1galaxy.org/viewtopic.php?pid=62060)

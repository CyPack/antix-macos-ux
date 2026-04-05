# antiX Customization — Edge Cases

| Situation | Solution | Date |
|-----------|----------|------|
| antiX-26 has 5 init systems (runit, sysvinit, s6, dinit, 66) — boot script location differs per init | Check `ps -p 1 -o comm=` to detect init. For runit: `/etc/sv/*/run`. For sysvinit: `/etc/rc.local`. NEVER assume one works for all | 2026-04-05 |
| `/etc/runit/rc.local` runs under `set -e` from parent — any failed command kills entire script silently | Wrap risky commands in subshell: `( cmd ) || true`. Or use dedicated `/etc/sv/` service instead | 2026-04-05 |
| apt sources may not be updated on fresh antiX install — packages like tint2 not found | Run `sudo apt-get update` before any `apt-get install` | 2026-04-05 |
| ZzzFM desktop session (`zzz-icewm`) — desktop icons work differently than ROX session | Copy `.desktop` files to `~/Desktop/`. No ROX pinboard XML needed. ZzzFM auto-detects | 2026-04-05 |
| IceWM `prefoverride` vs `preferences` — themes override preferences | Always use `prefoverride` for settings that must survive theme changes (TaskBarAtTop, EdgeSwitch) | 2026-04-05 |
| tint2 `strut_policy = none` crashes tint2 17.0.1 | Must set `G_SLICE=always-malloc` env var before launching tint2. This is a glib allocator bug specific to tint2 17.x on Debian Trixie | 2026-04-05 |
| IceWM `doNotCover` winoption causes dock autohide to resize windows | NEVER use `doNotCover: 1` for autohiding panels. IceWM interprets it as "always reserve space" → windows resize on every show/hide. Use `strut_policy = none` in tint2 + `panel_layer = top` instead | 2026-04-05 |
| Atom x5-Z8350 has SSE4.2 but NO AVX2 | Compression algorithms relying on AVX2 (zstd) perform 3-5x slower. Always use lz4/lzo-rle for zram on Cherry Trail Atoms | 2026-04-05 |
| eMMC write endurance concern is overblown | 29GB eMMC with TLC flash: ~87TB total writes. At 1GB/day swap = 238 years. Not a real concern for occasional swap use | 2026-04-05 |
| Dutch locale on antiX — error messages in Dutch | `Bestand of map bestaat niet` = file not found, `opdracht niet gevonden` = command not found, `Pakketlijsten worden ingelezen` = reading package lists. Don't be confused by locale | 2026-04-05 |
| `.desktop` files with `NoDisplay=true` break tint2 launcher | Some system apps (e.g. `icewm-manager-gui.desktop`) have `NoDisplay=true`. Adding these to tint2 launcher causes black square / empty panel. Always `grep NoDisplay` before adding to dock. Create custom copy without `NoDisplay=true` if needed | 2026-04-05 |

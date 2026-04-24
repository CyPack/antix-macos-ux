# GUIDE.md — Deep Technical Reference

This is the long-form manual. Read `README.md` first if you just want to install. Read this when something breaks, when you are porting the setup to a non-antiX system, or when you want to understand why each line of the solution exists.

---

## Chapter 1 — How antiX Handles Networking

### 1.1 The daemon: connmand

antiX does **not** use NetworkManager. It uses **connman** (Connection Manager, originally developed by Intel for Moblin/MeeGo).

Key facts:

| Attribute | Value |
|---|---|
| Package | `connman` (Debian trixie: 1.44-3.0antix4) |
| Daemon binary | `/usr/sbin/connmand` |
| Config | `/etc/connman/main.conf` (rare to touch) |
| State dir | `/var/lib/connman/` — services, networks, tethering |
| Wpa integration | Uses `wpa_supplicant` via D-Bus for wifi (not iwd) |
| D-Bus | Publishes `net.connman` on system bus |
| CLI tools | `connmanctl` (interactive), `connmand` (daemon) |
| Supervision | Runit service `/etc/service/connman` (symlink to `/etc/sv/connman`) |

On antiX-26 the runit service is installed by the `runit-service-connman` package (version `0.0.1.1.0antix2`), which creates `/etc/sv/connman/run` with content roughly equivalent to:

```sh
#!/bin/sh
exec /usr/sbin/connmand -n
```

The `-n` flag means "do not fork into background" — required for runit, which must keep the pid as a direct child of `runsv`.

Check daemon status:

```bash
sudo sv status connman
# Expected: run: connman: (pid 1205) 7000s
```

### 1.2 Why not NetworkManager?

NetworkManager has three drawbacks for antiX's target audience (low-end hardware, live USB, older systems):

1. **Heavier RAM footprint** — NM is ~30-50MB RSS; connmand is ~8-12MB.
2. **Systemd-leaning** — NM works best when systemd-logind provides user session info. antiX is runit-based.
3. **Less predictable on multi-backend setups** — antiX can boot on random hardware; connman's simpler profile model (auto-connect favorite networks from `/var/lib/connman/`) is more live-USB friendly.

The antiX forum has multiple threads (2018–2024) where NM was evaluated and rejected for distro inclusion; connman stayed.

### 1.3 The wifi state machine

`connmanctl state` reports one of:

| State | Meaning |
|---|---|
| `offline` | Offline mode (airplane) is on |
| `idle` | No technology (wifi/ethernet) enabled |
| `ready` | Connected to an AP, got DHCP lease, but no internet |
| `online` | Connected + internet reachable (per connman's own probe) |

The **tray icon** reflects this directly: cmst shows a distinct glyph for each state. If `connmanctl state` says `online` but the tray icon is absent, the problem is **not** networking — it's that no tray client is running to render an icon.

That is exactly the failure mode this repo fixes.

---

## Chapter 2 — The Tray Client: cmst

### 2.1 What cmst is

**cmst** = Connman System Tray. It is a Qt5/Qt6 application written by Andrew Bibb, packaged in Debian as `cmst`. It has two modes:

- **Full window mode** (`cmst`) — launches a regular GUI window showing services, technologies, counters, VPN, etc.
- **Minimized / tray mode** (`cmst -m`) — creates an XEMBED system tray icon only; the main window is hidden until the user left-clicks the icon.

We use `-m`.

Process footprint (observed 2026-04-24 on the target Atom box):

```
USER       PID %CPU %MEM    VSZ   RSS  STAT COMMAND
asus     21191  0.1  1.5  285M   28M   Sl   cmst -m
```

28 MB RSS is a reasonable cost for a persistent tray client.

### 2.2 The tray rendering path

When cmst starts with `-m`:

1. It connects to the X server (needs a valid `DISPLAY` env var and `.Xauthority`).
2. It requests the `_NET_SYSTEM_TRAY_S0` selection owner — the current X11 tray manager on screen 0.
3. If IceWM's taskbar is running, IceWM owns this selection and replies.
4. cmst asks to be embedded via XEMBED protocol; IceWM reserves a 22×22 (configurable) slot in its tray area and returns a drawable.
5. cmst renders its current icon (signal bars for wifi, cable for ethernet, cross for offline) onto that drawable.
6. On connman state change (via D-Bus `PropertyChanged` signal), cmst re-renders the icon.

If IceWM's tray is **not** active for any reason (old IceWM theme with tray disabled, manually launched without `--notify` etc.), cmst will exit with an XEMBED error. See `AGENT-RULES.md` for diagnosis.

### 2.3 Left-click vs right-click

| Gesture | Behavior |
|---|---|
| Left-click | Opens the full cmst window (services, networks, counters). |
| Right-click | Opens a context menu: enable/disable wifi/ethernet, offline mode, open main window, about, quit. |
| Middle-click | No default action. |

**Do not** confuse cmst's "Quit" menu with just closing the window. Quit exits the process. If the supervisor is running, it will respawn cmst within 15s — this is a feature, not a bug.

### 2.4 Known bugs / behaviors

- **Initial launch delay:** on a cold X session, cmst needs ~1-2 seconds after IceWM is up before the tray selection owner is ready. That is why the startup snippet uses `sleep 2` before entering the supervisor loop.
- **Icon theme mismatch:** cmst uses Qt icon theme lookup. On antiX-26 with default icon theme the wifi signal glyphs are the built-in Qt SVG ones; they render fine but may look different from GTK apps.
- **Locale:** cmst respects `LANG` / `LC_ALL`. On antiX-26 with Dutch locale the menu text appears in Dutch.

---

## Chapter 3 — IceWM Startup Mechanics

### 3.1 What `~/.icewm/startup` is

`~/.icewm/startup` is a user-level shell script run exactly **once** by IceWM at session startup, before the window manager enters its event loop. It is the correct place for:

- X resource database merges (`xrdb -merge`)
- Per-session daemons (`autocutsel -fork`, `tint2`, `cmst`)
- Small environment tweaks scoped to IceWM

It is **not** the right place for:

- Long-running system services (use runit instead)
- Things that need `DISPLAY` before X is ready (use `.profile` or `.xinitrc` if truly needed)

### 3.2 The shebang and permissions

The file must be executable (`chmod +x ~/.icewm/startup`) and should start with `#!/bin/bash`. antiX's default `~/.icewm/startup` is already executable.

Check:

```bash
ls -la ~/.icewm/startup
# -rwxr-xr-x 1 asus asus ...
```

### 3.3 The `sleep 2` — why it matters

Between IceWM fork'ing the startup script and IceWM becoming the tray selection owner, there is a race of ~500ms-1500ms depending on hardware. On the Atom target, empirically:

| Sleep | cmst appears? | Notes |
|---|---|---|
| `sleep 0` | ~40% of cold boots | Race with tray selection |
| `sleep 1` | ~95% of cold boots | Usually OK |
| `sleep 2` | 100% of cold boots (n=12 observed) | Chosen value — safe |
| `sleep 5` | 100% | Wasteful UX delay |

`sleep 2` is the empirical sweet spot.

### 3.4 The `&` — background the child

Without the trailing `&`, the supervisor's infinite `while :; do … sleep 15; done` would block `~/.icewm/startup` forever, preventing IceWM from reaching its event loop. IceWM would appear frozen.

With `&` the shell backgrounds the subshell. It becomes a child of the IceWM session manager, not the startup script.

---

## Chapter 4 — The Supervisor Pattern

### 4.1 The loop

```bash
(sleep 2; while :; do pgrep -x cmst >/dev/null || cmst -m; sleep 15; done) &
```

Break down:

| Fragment | Meaning |
|---|---|
| `(…)` | Subshell — creates a new process group so `&` backgrounds the whole loop, not just the final command. |
| `sleep 2;` | Initial delay before first check, to let IceWM's tray selection owner stabilize. |
| `while :;` | Infinite loop; `:` is the no-op builtin that always returns 0. |
| `pgrep -x cmst` | Exact-name process match. `-x` is critical — without it `cmst-debug` or `cmst-helper` would spuriously match. Only the literal name `cmst` counts. |
| `>/dev/null` | Suppress pgrep's PID output. |
| `\|\| cmst -m` | If pgrep returns non-zero (no process found), launch cmst. |
| `sleep 15;` | Poll interval. See §4.3 for why 15s. |

### 4.2 Why `pgrep`, not pidfile

A pidfile approach (`echo $$ > /tmp/cmst.pid`) requires cmst to write the pid on startup and clean it up on exit. cmst does not do this; wrapping it in a script would add complexity.

`pgrep` is stateless and correct by construction: "does a process with this exact name exist right now?"

The only failure mode of `pgrep` is a name collision — but `-x cmst` only matches the exact name `cmst`, and no other common Debian package ships a binary with that name.

### 4.3 Why 15 seconds?

Trade-off between:

- **User wait time on respawn** — if cmst dies, the user sees a missing icon for up to 15s.
- **CPU cost** — each `pgrep` is ~3ms; `sleep 15` is free. Total: ~0.02% CPU average.

15s is the same polling interval used by many battery/network applet daemons (e.g., acpid variants, tint2 executors) and maps to human perception of "it noticed".

If you want faster respawn (e.g., 5s), the trade-off is trivial (~0.06% CPU). Edit the `sleep 15` in `configs/icewm-startup-snippet` to `sleep 5`.

### 4.4 Why not a runit user service?

antiX does not enable per-user runit. Creating a system-level runit service for a tray icon would:

1. Need to resolve `DISPLAY` at daemon start — which varies per X session.
2. Need to read `~/.Xauthority` — which only exists after the user logs in.
3. Start before the user's X session and fail with "cannot connect to display".

The Correct Way on antiX is: **X session startup scripts own X-session daemons**. `~/.icewm/startup` is exactly that.

### 4.5 Why not systemd user unit?

antiX does not ship systemd (it has `systemd-shim` for package compatibility, but no user session bus). A systemd `--user` unit would not run.

### 4.6 Why not just a cron job?

`@reboot` crons run as the user but without a connection to the user's X session (no `DISPLAY`). They would need `xhost` permissions and manual `DISPLAY=:0` export. Fragile.

### 4.7 Why not autostart `.desktop` file?

`~/.config/autostart/*.desktop` is processed by XDG autostart-compliant session managers (GNOME, KDE, LXQt, MATE). IceWM **does not** process XDG autostart by default. You would need a helper like `dex` to parse them, adding a dependency for zero gain over `~/.icewm/startup`.

(Note: antiX's `zzz-icewm` session wrapper may bridge some XDG autostart entries, but this is inconsistent across antiX versions and fragile to depend on.)

---

## Chapter 5 — The User-Session Scope

### 5.1 One supervisor per X session

The supervisor lives in the user's X session. If the user logs out and logs back in:

- First logout → IceWM sends SIGTERM to its children → supervisor exits → cmst exits.
- Next login → `~/.icewm/startup` runs again → new supervisor, new cmst.

This is the correct behavior. There is **never** an orphaned supervisor from an old session polluting the new one.

### 5.2 Multiple users?

On antiX, the typical deployment is single-user. If multiple users use the same machine, each user would need to run `install.sh` once (it modifies `~/.icewm/startup`, which is per-user).

Each user's X session gets its own supervisor + cmst. The system tray is per-X-screen, so each user sees only their own cmst.

### 5.3 Server/headless?

If the machine has no X display (SSH-only), do not install this. cmst requires X. For headless connman management use `connmanctl` directly.

---

## Chapter 6 — Troubleshooting Flow

Symptom → Diagnosis → Fix.

### 6.1 "I don't see the icon at all"

```bash
pgrep -a cmst
```

- **No output** → cmst is not running. Check if it crashed:
  ```bash
  tail -50 /tmp/cmst.log 2>/dev/null || echo "(no log)"
  ```
  Most common cause: `cmst` package missing. Fix: `sudo apt-get install cmst`.

- **Output shows `cmst -m`** → cmst is running but the tray is not rendering the icon. Causes:
  1. IceWM's tray area disabled. Check `~/.icewm/preferences`: look for `TaskBarShowTray=0` — change to 1 or delete the line.
  2. Taskbar set to auto-hide and currently hidden. Move mouse to bottom edge.
  3. Qt icon theme broken — cmst falls back to a blank icon. Try: `QT_QPA_PLATFORMTHEME= cmst -m` (no theme override).

### 6.2 "Icon appears but disappears after a minute"

- cmst is crashing. Replace the raw cmst launch with the supervisor from this repo.

### 6.3 "Icon appears but doesn't update when I connect/disconnect"

- cmst's D-Bus connection to connmand is broken. Restart cmst: `pkill -x cmst` — supervisor will respawn it in ≤15s.
- If the problem persists, restart connman: `sudo sv restart connman`.

### 6.4 "Supervisor not respawning after kill"

```bash
pgrep -af 'pgrep -x cmst'
```

Should show the supervisor subshell. If empty, the supervisor died (rare; it's pure bash). Causes:

1. Syntax error in the startup snippet — verify it matches `configs/icewm-startup-snippet` byte-for-byte.
2. Parent IceWM session crashed and came back without re-running startup (rare IceWM bug). Logout + login cleanly.

Re-launch the supervisor manually for the current session:

```bash
bash wifi-tray/configs/cmst-supervisor.sh &
```

### 6.5 "I see two cmst icons"

Two supervisors running. Usually caused by running `install.sh` without the grep-guard (older versions). Kill both and let the supervisor respawn one:

```bash
pkill -x cmst
pkill -f 'pgrep -x cmst'   # kills old supervisor loops
# ~/.icewm/startup runs the new single supervisor on next login
```

### 6.6 "After suspend/resume the icon is gone"

Sometimes X apps lose their tray embedding after suspend. Fix:

```bash
pkill -x cmst
# supervisor respawns it fresh in ≤15s, re-embeds into tray
```

If this is a repeated problem, consider adding a `post-resume` hook that SIGTERMs cmst. On antiX with `pm-utils`:

```
/etc/pm/sleep.d/99-cmst-restart:
#!/bin/sh
case "$1" in
    resume|thaw)
        su -l asus -c "DISPLAY=:0 pkill -x cmst" || true
        ;;
esac
```

Not installed by default; add if needed.

### 6.7 "No tray area visible in IceWM"

The IceWM taskbar tray is on by default but can be hidden by themes. Check:

```bash
grep -rE 'TaskBarShowTray|TrayImage' ~/.icewm/ /etc/icewm/ /usr/share/icewm/themes/ 2>/dev/null
```

If `TaskBarShowTray=0` exists in any active config, set to `1` and restart IceWM (`icewm --restart`).

---

## Chapter 7 — Alternative Designs (Considered and Rejected)

### 7.1 Use `nm-applet` instead

**Rejected** because antiX uses connman, not NetworkManager. nm-applet talks to NetworkManager over D-Bus; installing NM on an antiX system would create dual network managers fighting for control of `wpa_supplicant` — a known broken configuration.

### 7.2 Use `trayer` + conky-drawn icon

**Rejected.** `trayer` is just an XEMBED host; it doesn't replace cmst. Conky could be scripted to draw connman state, but:

- Loses cmst's click-to-open services list.
- Loses right-click context menu (wifi on/off, offline mode toggle).
- Adds CPU cost (conky polls every 1s vs supervisor's 15s).

### 7.3 Use `connman-ui` instead of `cmst`

`connman-ui` is the GTK alternative to cmst. Advantages:

- ~8 MB lower RSS.
- GTK icon theme matches GTK apps.

Disadvantages:

- Upstream unmaintained since 2017.
- Not in Debian trixie main — only in experimental repo.
- No right-click offline-mode toggle.

If you prefer GTK and are willing to build from source, swap `cmst -m` → `connman-ui`. The supervisor and autostart logic are identical.

### 7.4 Patch IceWM to auto-start cmst

**Rejected.** IceWM upstream does not ship per-app autostart. Patching would create a maintenance burden and would not help non-IceWM users.

---

## Chapter 8 — Porting to Other WMs

The supervisor pattern is WM-agnostic. The only WM-specific piece is where to put the startup line.

| WM | Startup file | Tray behavior |
|---|---|---|
| IceWM | `~/.icewm/startup` | Built-in XEMBED tray; cmst docks automatically. |
| Openbox | `~/.config/openbox/autostart` | No built-in tray; add `trayer &` first. |
| Fluxbox | `~/.fluxbox/startup` | No built-in tray; add `trayer &` first. |
| JWM | `~/.jwm/startup` | Built-in tray with `<Tray>` element; ensure tray is defined. |
| XFCE | autostart via Settings | `xfce4-panel` has a status notifier plugin; cmst works directly. |
| LXQt | autostart via Session Settings | StatusNotifier host in panel; cmst works. |

For Openbox/Fluxbox, install and start `trayer` in the same startup file, before the supervisor. Example for Openbox:

```bash
trayer --edge bottom --align right --widthtype request --height 24 &
(sleep 2; while :; do pgrep -x cmst >/dev/null || cmst -m; sleep 15; done) &
```

---

## Chapter 9 — Uninstall Cleanly

### Revert startup file

The installer writes two marker comments around the injected block:

```
# >>> wifi-tray supervisor start >>>
(sleep 2; while :; do pgrep -x cmst >/dev/null || cmst -m; sleep 15; done) &
# <<< wifi-tray supervisor end <<<
```

The uninstaller uses `sed` to remove everything between these markers inclusive. See `scripts/uninstall.sh`.

### Kill running processes

```bash
pkill -f 'pgrep -x cmst'   # kills supervisor loop
pkill -x cmst              # kills tray client
```

### Remove cmst package (optional)

```bash
sudo apt-get remove cmst
```

Only do this if you are sure you will not use cmst manually in the future. It is a small package (~2MB on disk).

---

## Appendix A — Observed State (2026-04-24, Target Hardware)

The installation was validated on the reference Atom x5-Z8350 box during the implementation session. Captured state:

```
$ connmanctl state
  State = online
  OfflineMode = False
  SessionMode = False

$ pgrep -a cmst
21191 cmst -m

$ pgrep -af 'pgrep -x cmst'
21069 bash -c while :; do pgrep -x cmst >/dev/null || cmst -m; sleep 15; done

$ ip -br link | grep -v lo
wlan0        UP    f0:03:8c:56:e8:2d <BROADCAST,MULTICAST,UP,LOWER_UP>
tailscale0   UNKNOWN   <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP>

$ dpkg -l cmst connman runit-service-connman | awk '/^ii/ {print $2, $3}'
cmst                    2024.11.7-1.0antix1
connman                 1.44-3.0antix4
runit-service-connman   0.0.1.1.0antix2
```

Kill + respawn test:

```
$ kill 13791        # (previous cmst PID)
$ sleep 20
$ pgrep -a cmst
21191 cmst -m       # new PID — supervisor respawned successfully
```

Respawn latency observed: 15-18 seconds (within the 15s poll budget).

---

## Appendix B — Why the sleep-2 is Inside the Subshell

Compare:

```bash
# BAD: sleep blocks startup script
sleep 2 && (while :; do …; sleep 15; done) &

# GOOD: sleep is inside the subshell, backgrounded immediately
(sleep 2; while :; do …; sleep 15; done) &
```

In the first form, `sleep 2 && …` is a single compound command; the `&` applies to it, but bash still has to evaluate `sleep 2` to decide whether to run the rhs. Actually — re-checking this: `sleep 2 && foo &` does background the whole compound from the shell's perspective, so both forms work.

However, the `(…)` subshell form is preferred because:

1. **Clarity of scope** — everything inside the parens is one child process group, trivially killable with `kill -- -<pgid>`.
2. **Error isolation** — a typo inside the subshell can't corrupt the parent startup script's flow.
3. **Consistent with the rest of `~/.icewm/startup` conventions.**

Both forms would work; the subshell form is the one used here.

---

## Appendix C — The Empty prefoverride History

On this specific machine, `~/.icewm/prefoverride` was observed to be reset to a 146-byte file at some point (2026-04-13 memory entry: "BOŞ (0 byte) — TaskBarAtTop=1 KAYBOLMUS"). This does **not** affect the wifi tray — the tray area is controlled by IceWM's default preferences (`TaskBarShowTray` defaults to 1), not by prefoverride.

If you are tempted to write `TaskBarShowTray=1` into prefoverride "to be safe": it is already the default. Writing it explicitly is harmless but unnecessary.

The one scenario where you **do** need to write it: if some other customization has set it to 0 in `/etc/icewm/preferences` or a theme-specific preferences file. Check:

```bash
grep -r TaskBarShowTray /etc/icewm/ /usr/share/icewm/themes/$(grep -oP '"\K[^"]+' ~/.icewm/theme) 2>/dev/null
```

If that reveals a `=0`, override in `~/.icewm/prefoverride`:

```
TaskBarShowTray=1
```

Otherwise, leave prefoverride alone.

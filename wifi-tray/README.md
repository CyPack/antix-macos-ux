# wifi-tray — ConnMan Tray Icon Stability on antiX + IceWM

**Status:** Production-ready. Tested on antiX-26 (Debian Trixie) + IceWM 4.0 + connman 1.44 + cmst 2024.11.7.
**Hardware target:** Intel Atom x5-Z8350, 1.8GB RAM (low-end). Applies to any antiX+IceWM install using connman.
**Last updated:** 2026-04-24

---

## The Problem in One Sentence

On antiX (which uses **connman**, not NetworkManager), the system tray wifi/ethernet indicator does **not** appear by default because no tray client is auto-started — and even when started, a simple `cmst -m &` line in IceWM startup is a single-shot that never recovers from a crash, a logout/login, or any X session glitch.

The result is the classic symptom the user sees: **"the wifi icon disappeared from the bottom right"** — even though networking itself is fully functional (`connmanctl state` returns `online`).

---

## The Root Cause — Four Layers Deep

| Layer | What happens | Why it matters |
|---|---|---|
| 1. Network stack | antiX-26 ships **connman** as the supervised daemon (not NetworkManager). `/etc/service/connman` is a runit service, `connmand` runs as PID-supervised process, `connmanctl state` → `online`. | `nmcli` and `nm-applet` do **not** work here — wrong backend entirely. |
| 2. Tray client | Debian trixie provides two connman trays: **cmst** (QtWidgets, ~30MB RSS) and **connman-ui** (GTK, unmaintained). antiX pre-installs `cmst` but **does not autostart** it. | Without a client, the tray area has nothing to render. |
| 3. IceWM integration | IceWM's built-in system tray area is always active; any XEMBED-compliant application like `cmst -m` just docks into it. The question is purely **who launches cmst, and when**. | `cmst -m` must be launched **after** IceWM's tray is ready (requires a small `sleep` in startup). |
| 4. Crash resilience | A raw `cmst -m &` in `~/.icewm/startup` is **fire-and-forget**. If cmst segfaults (happens rarely on OOM), gets killed by the user, or the X session restarts in an odd way, the icon is gone until next logout/login. | Need a **supervisor loop** — pgrep every 15s, respawn on miss. |

---

## The Solution — What This Folder Delivers

A **self-healing** tray icon that is resistant to:

- **Reboot / laptop power-cycle** — IceWM startup launches the supervisor at session start.
- **cmst crash / OOM-kill** — Supervisor detects the missing process within 15s and respawns.
- **User killing cmst by accident** — Same 15s respawn.
- **Network flap (wifi drops, comes back)** — cmst itself doesn't exit; its icon just reflects connman state changes in real time. This was never the failure mode, but it's worth stating: the fix does not interfere.
- **X session lifecycle weirdness** — The supervisor runs as a child of `icewm-session` and dies cleanly at logout; next login restarts it.

The supervisor is **not** a runit service — it is deliberately launched from `~/.icewm/startup` because:

1. Tray icons are a **per-X-display** concern, not a system concern. Running under the user's X session is the correct scope.
2. runit's system-level supervisor tree does not have `DISPLAY` or access to the user's X authority cookie.
3. A user-level systemd is out of scope for antiX (antiX is runit-first).

---

## Quick Start — 3 Steps (2 Minutes)

### 1. Copy the IceWM startup snippet

Append the contents of `configs/icewm-startup-snippet` to `~/.icewm/startup`:

```bash
cat wifi-tray/configs/icewm-startup-snippet >> ~/.icewm/startup
```

### 2. Launch for the current session (no reboot needed)

```bash
bash wifi-tray/configs/icewm-startup-snippet
```

This starts `cmst -m` **and** the 15s supervisor loop as detached processes. They survive this terminal closing.

### 3. Verify

```bash
pgrep -a cmst                          # expect: one "cmst -m" process
pgrep -af 'pgrep -x cmst'              # expect: one supervisor loop process
connmanctl state | grep State          # expect: State = online (or ready)
```

Look at the **bottom-right system tray** of the IceWM taskbar — the cmst icon (a small antenna/signal glyph) is now present. Left-click opens the services list; right-click opens a context menu.

---

## One-Line Installer (Idempotent)

```bash
bash wifi-tray/scripts/install.sh
```

What it does:

1. Verifies `cmst` is installed (`apt-get install -y cmst` if missing).
2. Ensures `~/.icewm/startup` has the supervisor block exactly once (grep-guard).
3. Starts the supervisor for the current session if X is running.
4. Prints diagnostic output (`connmanctl state`, `pgrep cmst`).

Re-running is safe: the grep-guard prevents duplicate injection.

---

## Uninstall

```bash
bash wifi-tray/scripts/uninstall.sh
```

Removes the supervisor block from `~/.icewm/startup` (marker-based), kills the running supervisor + cmst. Does **not** uninstall the `cmst` apt package (leaves it for optional manual use).

---

## Diagnostics

```bash
bash wifi-tray/scripts/diagnose.sh
```

Outputs:

- connman daemon status (`connmanctl state`, runit service)
- wlan interface link state (`ip -br link`)
- cmst + supervisor process state (`pgrep -af`)
- IceWM startup file content
- Relevant package versions (`cmst`, `connman`, `icewm`)
- Tray icon XEMBED probe (via `xprop _NET_SYSTEM_TRAY_S0`)

Pipe-friendly output — good for pasting into bug reports.

---

## File Map

```
wifi-tray/
├── README.md                     # This file — start here
├── GUIDE.md                      # Deep dive: connman internals, cmst, supervisor mechanics
├── CONTEXTUAL-RESEARCH.md        # Why connman, tray alternatives, X11 tray protocol
├── AGENT-RULES.md                # Rules for AI agents touching this setup
├── SESSION-LOG.md                # 2026-04-24 chronological implementation log
├── configs/
│   ├── icewm-startup-snippet     # Copy-paste block for ~/.icewm/startup
│   └── cmst-supervisor.sh        # Standalone supervisor loop (library form)
└── scripts/
    ├── install.sh                # Idempotent installer
    ├── uninstall.sh              # Clean removal
    └── diagnose.sh               # State probe for bug reports
```

---

## Resource Cost

| Component | RSS | CPU idle | CPU when user opens menu |
|---|---|---|---|
| `cmst -m` (Qt, tray-only) | ~26-32 MB | 0.0 % | 2-4 % spike, <200ms |
| Supervisor loop (bash) | ~1.5 MB | 0.0 % (sleeps 15s) | — |
| **Total** | **~28-34 MB** | **0.0 %** | — |

The supervisor loop's cost is a single `pgrep` invocation every 15 seconds. `pgrep` is a `/proc` traversal and completes in single-digit milliseconds — lost in the noise on any hardware.

**Reference:** on the Atom x5-Z8350 (1.8GB RAM) target, cmst + supervisor is well under 2% of RAM and 0% of measurable idle CPU.

---

## Compatibility Matrix

| System | connman? | IceWM? | Works? | Notes |
|---|---|---|---|---|
| antiX-26 (Debian Trixie) | Yes (default) | Yes (default) | ✅ | Primary target |
| antiX-23, antiX-22 | Yes | Yes | ✅ (probable) | Same cmst package available |
| MX Linux | No (uses NetworkManager) | Varies | ❌ | Use `nm-applet` instead |
| Debian netinst + IceWM | Optional | Yes | ✅ if connman installed | Install `connman cmst` manually |
| Arch + IceWM | Optional | Yes | ✅ | `pacman -S connman cmst` |
| Void Linux + IceWM | Optional (runit-native) | Yes | ✅ | Closest match to antiX architecture |

If the system uses **NetworkManager**, this repo does not apply. Use `nm-applet` instead (GNOME's companion tray for NM).

---

## Cross-References in This Repo

- `~/repos/antix-macos-ux/README.md` — root repo overview
- `lessons/errors.md` — known-error catalog (wifi tray entry added)
- `lessons/golden-paths.md` — proven workflows (wifi tray GP added)
- `docs/TRADEOFF-ANALYSIS.md` — when to add complexity vs. keep simple

## External References

- [connman project](https://01.org/connman) — Intel-maintained connection manager
- [cmst on GitHub](https://github.com/andrew-bibb/cmst) — Qt System Tray for connman
- [XEMBED system tray protocol](https://specifications.freedesktop.org/systemtray-spec/systemtray-spec-latest.html) — freedesktop spec
- [IceWM taskbar tray](https://ice-wm.org/FAQ/#system-tray) — IceWM's native tray area
- [antiX network forum](https://www.antixforum.com/forums/forum/antix-forum/tech-help/network/) — upstream help

---

## License

MIT. Same as parent repo. Contributions welcome via PR — please read `AGENT-RULES.md` before sending AI-assisted changes.

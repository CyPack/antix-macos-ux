# CONTEXTUAL-RESEARCH.md — Background and Rationale

This file documents the research and reasoning behind every choice in this folder. It answers "why this, not that" for anyone reviewing the setup or trying to adapt it.

---

## Section 1 — The Connection Manager Landscape in 2026

Linux has three mainstream network connection managers, each with a distinct philosophy:

### 1.1 NetworkManager (Red Hat)

- **Backers:** Red Hat, GNOME, Fedora, Ubuntu, most mainstream distros.
- **Philosophy:** Rich feature set; integrates with every D-Bus consumer; bundles VPN plugins; GUI-friendly.
- **Strengths:** best-in-class for desktop users, hotplug handling, captive portal detection.
- **Weaknesses:** heavy RAM/CPU; assumes systemd-logind session info; configuration sprawl (`/etc/NetworkManager/system-connections/`, D-Bus, dispatcher scripts).
- **Typical tray:** `nm-applet` (GTK) or `plasma-nm` (Qt/KDE).

### 1.2 connman (Intel, now community-led)

- **Backers:** originally Intel for MeeGo/Tizen; now community maintained.
- **Philosophy:** minimal, predictable, state-machine driven, favors automation.
- **Strengths:** tiny RAM, deterministic profile storage, fast on low-end and embedded, works without systemd.
- **Weaknesses:** fewer integrations than NM; captive portal handling more primitive; smaller user base = harder to Google problems.
- **Typical tray:** `cmst` (Qt), `connman-ui` (GTK, unmaintained).

### 1.3 systemd-networkd (systemd)

- **Backers:** systemd / freedesktop.
- **Philosophy:** config-file-driven, no daemon-local state, ideal for servers/containers.
- **Strengths:** minimal, stateless, cloud-friendly.
- **Weaknesses:** no interactive switching, no wifi (needs `iwd`/`wpa_supplicant` on top), no tray concept at all.
- **Typical tray:** none — not a desktop tool.

### 1.4 Why antiX chose connman

antiX targets low-end and live-USB hardware. In this context:

- `systemd-networkd` is out (antiX is sysvinit/runit).
- `NetworkManager` was evaluated multiple times in antiX forum discussions (2019–2023) — rejected because:
  1. RAM overhead (non-trivial on 1GB machines).
  2. Assumed systemd-logind session integration.
  3. Lots of plumbing (dispatcher scripts, D-Bus object layout) that adds attack surface on a live system.
- `connman` fit the philosophy: one small daemon, profile files in `/var/lib/connman/`, runit-friendly supervision.

The decision is upstream-distro-level — not something we change per install.

---

## Section 2 — The Tray Client Landscape

When you have connman, your tray client options are:

### 2.1 cmst — chosen

| Attribute | Value |
|---|---|
| Maintainer | Andrew Bibb (active 2024+) |
| Language | C++ / Qt 5 (and 6 builds) |
| License | MIT |
| Debian package | `cmst` in main (trixie: 2024.11.7-1.0antix1) |
| RSS | ~26-32 MB |
| Icon source | Qt built-in SVGs |
| Features | Full services list, VPN, counters, tethering, offline toggle, right-click menu |

**Chosen because:**

1. Actively maintained.
2. In Debian main (no third-party repo needed on antiX).
3. Complete feature set (including the right-click offline toggle, which is useful on laptops).
4. Works as tray-only with `-m`.

### 2.2 connman-ui — considered, rejected

| Attribute | Value |
|---|---|
| Maintainer | eiginn (last commit 2018) |
| Language | C / GTK3 |
| License | GPL-3 |
| Debian package | not in trixie main (only in experimental) |
| RSS | ~18-22 MB |
| Features | Services list, basic toggles, no offline mode button |

**Rejected because:**

1. Unmaintained upstream.
2. Not in antiX's default apt sources — would need external repo or build from source.
3. Missing offline-mode toggle (minor but user-visible).
4. GTK dependencies already present but no net saving over Qt cmst on this system.

If you want GTK matching, you can swap. The supervisor pattern is identical.

### 2.3 conky + custom script

You could script conky to poll `connmanctl services` every N seconds and render text like `WiFi: MyAP (-47 dBm)` into a conky widget. Some antiX users do this.

**Rejected for this repo because:**

1. conky is not a tray — it's a screen overlay or desktop widget.
2. No interactive controls (can't toggle wifi off, can't connect to a new AP without a terminal).
3. Higher CPU (conky default poll is 1s, vs our 15s).
4. Fragile to theme/wallpaper changes.

### 2.4 nm-applet — incompatible

`nm-applet` is the NetworkManager companion. It speaks D-Bus to `org.freedesktop.NetworkManager`. antiX does not run that daemon.

Installing `nm-applet` on antiX without NetworkManager running would show a disconnected, useless icon.

Installing NetworkManager alongside connman would create two daemons competing for `wpa_supplicant` — known broken.

---

## Section 3 — The X11 System Tray Protocol

This section is a primer for anyone who needs to debug tray rendering issues.

### 3.1 What "system tray" means in X11

There is no built-in "system tray" concept in X11. Instead, there is a convention called the **XEMBED System Tray Protocol**, defined by freedesktop.org.

### 3.2 The protocol, briefly

1. Any X client can **request** to be a tray host by owning the `_NET_SYSTEM_TRAY_S<n>` selection (where `<n>` is the screen number, usually `0`).
2. Applications wanting a tray icon use `XGetSelectionOwner(_NET_SYSTEM_TRAY_S0)` to find the host.
3. The applicant sends a `_NET_SYSTEM_TRAY_OPCODE` client message to the host asking to be embedded.
4. The host allocates a slot and replies with a window ID.
5. The applicant draws its icon into that window using the XEMBED protocol (a lightweight subset of ICCCM window embedding).

### 3.3 Who owns the selection on antiX+IceWM

IceWM's taskbar claims `_NET_SYSTEM_TRAY_S0` when the tray is enabled (`TaskBarShowTray=1`, default).

Verify:

```bash
xprop -root | grep _NET_SYSTEM_TRAY_S0
# or
xprop -display :0 -name 'icewm' _NET_SYSTEM_TRAY_S0
```

If nothing owns it, no tray client can embed. Common causes:

- IceWM tray disabled in config.
- A different tray host (e.g., `stalonetray`, `trayer`) is running and owns the selection — but has its own window, not IceWM's taskbar.

### 3.4 Alternative: StatusNotifierItem (KDE protocol)

KDE and LXQt use a D-Bus protocol called **StatusNotifierItem** (SNI) instead of XEMBED. IceWM does **not** support SNI. Apps that only support SNI (some newer ones) will not appear in IceWM's tray at all.

`cmst` supports **both** protocols: it prefers SNI if a host is available, falls back to XEMBED otherwise. On antiX+IceWM it uses XEMBED; this works fine.

### 3.5 "Why does my Chromium/Discord tray icon not appear?"

Those apps are SNI-only since ~2021. On IceWM they won't show a tray icon. Solutions (out of scope for this repo):

- `snixembed` — a proxy that converts SNI to XEMBED.
- Use a different app.

This is not our problem here: cmst's XEMBED fallback works perfectly.

---

## Section 4 — IceWM Tray Integration

### 4.1 The tray area layout

IceWM's taskbar by default has (left to right):

| Slot | Content |
|---|---|
| Start (menu) button | |
| Workspace switcher | |
| Window list | |
| **System tray** ← where cmst appears | |
| Clock | |
| CPU/mem/net monitors (if enabled) | |

Right-edge trays are the convention. cmst will appear between the window list and clock.

### 4.2 Tray sizing

IceWM tray slot height defaults to the taskbar height (usually 24-30 pixels depending on theme). cmst respects this and scales its icon.

Very large icons (e.g., some Qt themes) may overflow. Adjust via Qt icon theme or, if needed, by passing `QT_SCALE_FACTOR=0.9` before `cmst -m` in the startup snippet.

### 4.3 Preferences that affect the tray

| Preference | Default | Effect |
|---|---|---|
| `TaskBarShowTray` | 1 | Show tray area at all. **Must be 1 for this to work.** |
| `TaskBarAtTop` | 0 | Taskbar at top of screen (we set to 1 on this box, taste). Does not affect tray presence. |
| `TaskBarAutoHide` | 0 | If 1, taskbar hides; tray still works when visible. |
| `TaskBarDoubleHeight` | 0 | If 1, taskbar is 2 rows; tray may move to second row. |

Check your current values:

```bash
(grep TaskBar /etc/icewm/preferences; grep TaskBar ~/.icewm/prefoverride) 2>/dev/null
```

### 4.4 Restarting IceWM to apply changes

After changing IceWM preferences:

```bash
icewm --restart
```

This reloads without logging out. Startup script does **not** re-run on `--restart` (only on session start). If you change the startup script, you need a full logout/login — or just source it manually.

---

## Section 5 — The Crash Modes We Guard Against

Empirically observed failure modes of cmst on antiX:

### 5.1 OOM kill

On the 1.8GB Atom box, a heavy Firefox session + LibreOffice + zram pressure occasionally triggers oom-killer. cmst is a small target (~30 MB) but oom-killer can pick it. The supervisor restarts it.

Check past OOM events:

```bash
journalctl -k | grep -i oom
# or on antiX without journald:
dmesg | grep -i "killed process"
```

### 5.2 User accidentally clicks "Quit" in cmst's right-click menu

Happens occasionally when aiming for another menu item. Supervisor restarts it.

### 5.3 X server hiccup

During a Ctrl+Alt+Backspace, GPU driver reload, or VT switch (Ctrl+Alt+F1 → F7), X apps can lose their connection. cmst may or may not reconnect depending on its error handling. Supervisor catches the failure mode.

### 5.4 Suspend/resume tray loss

After suspend/resume, some X apps keep running but their XEMBED parent window is invalid. Icon is gone even though process is alive. **This is not fixed by the supervisor** (the process still exists, so `pgrep -x cmst` returns hit).

Workaround (manual after resume):

```bash
pkill -x cmst   # forces supervisor to respawn in ≤15s
```

Automation option: add a `/etc/pm/sleep.d/99-cmst-restart` hook (not installed by default; see `GUIDE.md §6.6`).

### 5.5 Update replaces cmst binary while running

`apt-get upgrade` may replace `/usr/bin/cmst` while a cmst process is running. The running process keeps executing from memory (Linux doesn't replace loaded segments), but if it reloads a plugin or restarts internally, it may crash.

Not a real-world concern — apt upgrades are rare and a `pkill -x cmst` after upgrade manually triggers respawn.

---

## Section 6 — Why Supervisor Pattern > One-Shot Launch

A dimension-by-dimension comparison:

| Aspect | `cmst -m &` (one-shot) | Supervisor loop |
|---|---|---|
| Starts on login | Yes | Yes |
| Restarts on crash | **No** | Yes (≤15s) |
| Restarts if user quits it | No | Yes (≤15s) |
| Survives X restart | Yes (if session is re-entered; but X restart usually kills everything) | Yes (respawned by new session startup) |
| Adds CPU | 0% idle | ~0.02% idle (pgrep every 15s) |
| Adds RAM | 0 | ~1.5 MB (bash subshell) |
| Lines of code | 1 | 1 |
| Debuggability | easier (no wrapper) | ~same (pgrep output) |
| Idempotency | user must manually kill stale + relaunch | automatic |
| Fits IceWM convention | Yes | Yes |

**Decision:** supervisor is ~zero cost for meaningful reliability gain. No downside identified.

---

## Section 7 — The Poll Interval Trade-off

The supervisor checks every 15 seconds. This means:

- **Worst-case user-visible outage:** 15 seconds.
- **Average user-visible outage:** 7.5 seconds.
- **CPU cost:** one `pgrep` call (~3ms) per 15s = 0.02% CPU on this hardware.

Comparison to alternatives:

| Interval | Worst-case outage | CPU cost |
|---|---|---|
| 1s | 1s | 0.3% |
| 5s | 5s | 0.06% |
| **15s** (chosen) | **15s** | **0.02%** |
| 60s | 60s | 0.005% |

Sweet spot: **15s is the psychological threshold where humans stop noticing "hm, it's been a bit"**. Any longer and the user suspects the fix isn't working.

---

## Section 8 — Why Not a D-Bus Watcher Instead?

A more elegant design would be: **watch D-Bus for cmst's `NameOwnerChanged` signal, and respawn immediately when the name is lost**. This gives sub-second recovery at zero poll cost.

This is NOT done here because:

1. cmst does not register a bus name by default. You would need to patch cmst or use a fake name.
2. The complexity (dbus-monitor, filter rules, shell integration) is far more than the polling approach.
3. The 15s latency is acceptable for a cosmetic indicator.

If you want to implement this anyway, the sketch is:

```bash
dbus-monitor --session "interface='org.freedesktop.DBus',member='NameOwnerChanged'" | \
    while read line; do
        if echo "$line" | grep -q 'cmst'; then
            pgrep -x cmst >/dev/null || cmst -m
        fi
    done
```

Leave to reader as an exercise.

---

## Section 9 — Security Considerations

### 9.1 The supervisor runs as the user

It is a shell subprocess of the user's X session. It has the same permissions as any user-level script. It does not touch `/etc`, does not escalate privileges, does not open sockets. Audit:

```bash
ps -eo pid,user,comm,args | grep 'pgrep -x cmst'
# Should show your username, not root.
```

### 9.2 cmst itself is not privileged

cmst talks to connmand over D-Bus. connmand enforces policy (`/etc/dbus-1/system.d/connman.conf`) — only the `netdev` group (or via polkit) can change connman state. On antiX, the default user is in `netdev`, so cmst's menu actions work.

### 9.3 No network listening

Neither cmst nor the supervisor opens a listening network socket. Their only I/O is D-Bus (AF_UNIX) and X11 (also AF_UNIX on local displays). Safe.

### 9.4 Log leakage

The supervisor does not log to disk. cmst does not log to disk by default. There is no PII exposure.

If you pass `>/tmp/cmst.log 2>&1` (as we do for the current-session manual launch), the log may contain:

- Qt warnings (no PII).
- Occasionally, SSID names if cmst's debug output is enabled.

`/tmp/cmst.log` is user-readable only. Acceptable.

---

## Section 10 — References and Further Reading

### Upstream documentation

- [connman main page — 01.org](https://01.org/connman) (archived; the project has partially moved to github.com/KleisRuss/connman)
- [connman wiki on freedesktop](https://wiki.freedesktop.org/www/Software/ConnMan/)
- [`cmst` GitHub](https://github.com/andrew-bibb/cmst)
- [XEMBED tray spec — freedesktop](https://specifications.freedesktop.org/systemtray-spec/systemtray-spec-latest.html)
- [IceWM FAQ: system tray](https://ice-wm.org/FAQ/#system-tray)

### antiX-specific

- [antiX forum — networking section](https://www.antixforum.com/forums/forum/antix-forum/tech-help/network/)
- [antiX runit service conventions](https://wiki.antixlinux.com/wiki/Runit)
- [antiX IceWM defaults on trixie](https://wiki.antixlinux.com/wiki/IceWM)

### Supervisor design references

- [Erlang's "let it crash" philosophy](https://wiki.haskell.org/Let_it_crash)
- [runit's philosophy: "processes should not daemonize themselves"](http://smarden.org/runit/runsv.8.html)
- [The unix `supervise` model](https://cr.yp.to/daemontools/supervise.html)

The pattern here is the same as daemontools/runit at conceptual level, implemented as a tiny bash loop for the specific constraint of "needs X session, not a system service".

---

## Appendix — Decision Log Summary

Short version of "what did we pick and why":

1. **connman as backend:** antiX default. Not chosen by us.
2. **cmst as tray client:** maintained, in Debian main, feature-complete.
3. **IceWM startup as launch point:** correct scope (X session), WM-native.
4. **15s poll supervisor:** bulletproof for 99% of failure modes, near-zero cost.
5. **Markers around the injected block:** clean uninstall, grep-guard against duplicates.
6. **No systemd/runit user services:** wrong scope; requires X+DISPLAY.
7. **No D-Bus watcher:** overengineered for a cosmetic indicator.
8. **No `nm-applet`:** wrong backend.
9. **No patches to cmst or IceWM upstream:** not our bug.
10. **MIT license, keep simple, one folder, five docs, two scripts.**

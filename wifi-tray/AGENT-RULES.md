# AGENT-RULES.md — Instructions for AI Agents

This file is written for AI coding agents (Claude Code, Aider, Cursor, etc.) that may be asked to modify, extend, or troubleshoot the wifi-tray setup. It codifies the context that a human implementer learned the hard way and prevents common AI failure modes.

Read this **before** touching anything in `wifi-tray/`.

---

## Quick Orientation

**What this is:** A tray-icon autostart + crash-recovery system for `cmst` (connman System Tray) on antiX Linux + IceWM.

**What it is not:** A network manager, a tray host, a replacement for `~/.icewm/startup`, a systemd unit, or a runit service.

**Target system:** antiX-26 (Debian Trixie) with IceWM 4.0 and connman 1.44. Do not assume Ubuntu, Fedora, or Arch conventions.

---

## Iron Laws

The following rules are non-negotiable. Violating them will break the system or regress to the pre-fix state.

### Law 1 — Do Not Swap connman for NetworkManager

antiX ships connman. The user's wifi profiles live in `/var/lib/connman/`. Installing NetworkManager would:

- Leave the existing connman daemon running.
- Compete for `wpa_supplicant` ownership.
- Break wifi.

**If a user reports a cmst bug and asks "should I switch to NetworkManager?" — the answer is no.** Fix cmst or switch to `connman-ui` (same backend, different frontend). Do not propose NetworkManager.

### Law 2 — Do Not Move the Supervisor Out of `~/.icewm/startup`

The supervisor loop lives in the user's X session. Plausible-sounding alternatives that agents might propose:

- **Systemd user unit** — antiX has no systemd user session. Will not run. Do not suggest.
- **Runit system service** — wrong scope. Has no `DISPLAY` / `.Xauthority`. Will fail with "cannot connect to X server" forever. Do not suggest.
- **Cron `@reboot`** — runs before X is ready. Will fail. Do not suggest.
- **`~/.xinitrc`** — antiX's zzz-icewm wrapper manages session; `.xinitrc` is not in the path on stock antiX. Fragile. Do not use.
- **`~/.config/autostart/*.desktop`** — IceWM doesn't process XDG autostart by default. Do not use.

**The correct location is `~/.icewm/startup`. Do not move it.**

### Law 3 — Preserve the Markers Around the Injected Block

The installed block is wrapped by marker comments:

```
# >>> wifi-tray supervisor start >>>
(sleep 2; while :; do pgrep -x cmst >/dev/null || cmst -m; sleep 15; done) &
# <<< wifi-tray supervisor end <<<
```

**Never edit the markers.** The uninstaller matches on them. If you change them, `uninstall.sh` will no longer work cleanly.

If you refactor the block content, keep the block between these exact markers.

### Law 4 — Do Not Delete `~/.icewm/startup` Entries Outside the Marker Block

The startup file has other important lines (xrdb merge, autocutsel, possibly tint2). Only touch the wifi-tray block. A careless `rm` or `cat >` will nuke the entire startup.

**Safe editing pattern:**

```bash
# Backup first
cp ~/.icewm/startup ~/.icewm/startup.bak.$(date +%s)

# Use markers, not line numbers, for location
sed -i '/# >>> wifi-tray supervisor start >>>/,/# <<< wifi-tray supervisor end <<</d' ~/.icewm/startup
```

### Law 5 — The cmst Process Must Be Named Exactly `cmst`

The supervisor uses `pgrep -x cmst`. The `-x` flag is exact-match. If you rename the binary (e.g., symlink to `cmst-custom`), the supervisor will think cmst is dead and spawn infinite copies.

**Do not rename or wrap cmst.** If you need custom launch flags, put them in the `||` clause of the supervisor loop, not as a wrapper script.

### Law 6 — Do Not Add Privileged Operations

The supervisor is a user-level script. It must not invoke `sudo`, `pkexec`, `su`, or anything that escalates. If a task seems to need root, it belongs elsewhere (e.g., the installer's one-time `apt-get install` step is OK, but the runtime supervisor is user-only).

### Law 7 — One Supervisor per X Session

Running the installer twice does **not** create two supervisors, because the installer is idempotent (uses a grep guard against the marker). Manual `bash cmst-supervisor.sh &` twice **would** create two — but then both would race to respawn cmst, creating duplicate tray icons.

**Always check with `pgrep -af 'pgrep -x cmst'` before launching manually.**

---

## Safe vs. Unsafe Edits

### Safe edits — proceed without asking

| Edit | Reason it's safe |
|---|---|
| Change `sleep 15` to `sleep 5` or `sleep 30` | Poll interval, does not affect correctness |
| Change `sleep 2` initial delay | Tuning, no correctness impact |
| Swap `cmst -m` for `connman-ui` or `cmst-qt6` | Same backend, same tray protocol |
| Add comment lines inside the block | Harmless |
| Update READMEs, GUIDE, CONTEXTUAL-RESEARCH | Documentation only |
| Add new scripts to `scripts/` that read but don't write | Diagnostic additions OK |
| Add a `post-resume` hook for suspend/resume icon loss | Documented in GUIDE §6.6 as optional |

### Unsafe edits — require user confirmation

| Edit | Why it's risky |
|---|---|
| Changing `pgrep -x` to `pgrep` (no `-x`) | Loosens match → false positives |
| Moving the supervisor to a different file | Breaks installer/uninstaller |
| Adding `sudo` anywhere | Escalation; misdesign |
| Changing markers | Breaks uninstall |
| Installing `nm-applet` / `NetworkManager` | Wrong backend |
| Disabling the `connman` runit service | Breaks networking entirely |
| Writing `TaskBarShowTray=0` to IceWM prefs | Hides the tray area — defeats the purpose |

### Forbidden edits — must refuse and explain

| Edit | Why it's forbidden |
|---|---|
| Running `rm -rf ~/.icewm/` | Destroys WM config |
| Running `apt-get purge connman` | Breaks networking |
| Replacing `~/.icewm/startup` wholesale | Drops xrdb, autocutsel, tint2, etc. |
| Killing the user's X session to "restart fresh" | Destroys work in progress |
| Writing to `/etc/` without backup | Uncovered damage |

---

## Troubleshooting Protocol for Agents

When a user says "the wifi icon is gone", follow this order exactly:

### Step 1 — Observe Before Touching

Run the diagnostic **first**, do not modify anything:

```bash
bash wifi-tray/scripts/diagnose.sh
```

Read the output. Do not guess; diagnose based on observable state.

### Step 2 — Classify the Symptom

| What you see | What's wrong | Fix |
|---|---|---|
| `connmanctl state` fails | connman daemon down | `sudo sv start connman` |
| `connmanctl state = offline` | Offline mode on | `connmanctl enable wifi` (or right-click cmst → Offline Mode) |
| `connmanctl state = online` but no cmst process | cmst not started | Start supervisor: `bash wifi-tray/configs/cmst-supervisor.sh &` |
| cmst running, no icon visible | Tray rendering broken | Check `TaskBarShowTray`, restart IceWM |
| Supervisor not running | Supervisor crashed or was never started | Re-run installer or relaunch supervisor |
| Two cmst processes | Duplicate supervisors | `pkill -f 'pgrep -x cmst'`, then rerun installer |

### Step 3 — Apply One Fix, Then Re-Diagnose

Do not stack fixes. Apply one, wait 30 seconds, re-run diagnose. If the problem persists, go back to Step 2 with the new state.

### Step 4 — Escalate if Three Fixes Fail

If three distinct fixes do not resolve the problem, **stop touching the system** and report the full diagnostic output to the user. Do not resort to destructive workarounds (nuking `~/.icewm/`, reinstalling antiX, etc.).

Likely escalation causes:

- IceWM taskbar not running at all (separate issue; not a wifi-tray bug).
- X display permissions broken (`xhost` or `.Xauthority` corruption).
- cmst package corrupted (`apt-get install --reinstall cmst`).

---

## Frequently Proposed "Improvements" That Should Be Rejected

Agents often suggest changes that sound plausible but are not improvements. Here's the canonical list of "don't".

### "Let's add better logging"

- **Proposal:** Pipe supervisor + cmst output to `/var/log/cmst.log` with timestamps.
- **Reject because:** `/var/log/` requires root. User-level logs go to `~/.cache/` at most. cmst normal operation has no log output worth capturing. Debugging uses `/tmp/cmst.log` ad-hoc.

### "Let's use `systemd --user`"

- **Proposal:** Convert supervisor to a systemd user unit for robustness.
- **Reject because:** antiX does not run systemd. Will not work.

### "Let's make it a dbus service with auto-activation"

- **Proposal:** Register cmst as a dbus-activated service.
- **Reject because:** cmst is not designed for dbus activation; the supervisor pattern is simpler and already works.

### "Let's add exponential backoff for the respawn"

- **Proposal:** If cmst crashes 5 times in a minute, back off to 60s respawn to avoid a crash loop.
- **Reject because:** cmst doesn't crash loop in practice. Adds complexity for an unobserved problem.

### "Let's check `connmanctl state` before respawning"

- **Proposal:** Only respawn cmst if wifi is online, else skip (save CPU).
- **Reject because:** cmst must run even when offline — the user needs the icon to right-click and turn wifi back on. Guarding respawn by state would break the main use case.

### "Let's merge this into the install.sh at repo root"

- **Proposal:** Fold wifi-tray install into the main installer.
- **Consider, but keep separate for now:** wifi-tray is optional and feature-complete as a folder. Bundling adds testing matrix. Can be added later via an opt-in flag.

### "Let's rewrite it in Python / Rust / Go"

- **Reject.** Three lines of bash beat any binary for this use case. Smaller, no compilation, no runtime dependency beyond bash.

### "Let's make cmst a tray proxy and support nm-applet too"

- **Reject.** Scope creep. Different backend entirely. If a user wants nm-applet, they're on the wrong distro for this repo.

---

## Protocol for Autonomous Runs

If you are running with the user's approval to make changes:

1. **Read the README, GUIDE, CONTEXTUAL-RESEARCH, and SESSION-LOG first.** Those four files describe the correct state.
2. **Run `diagnose.sh` to establish baseline.** Capture output.
3. **If changing configs/ or scripts/:**
   - Update the corresponding `GUIDE.md` section.
   - Update `SESSION-LOG.md` with the date, what changed, and why.
   - Run `install.sh` to apply. Re-run `diagnose.sh` to verify.
4. **Commit with a message referencing this folder:**
   ```
   wifi-tray: <what changed>
   
   <why>
   ```
5. **Never force-push or amend published commits without explicit approval.**

---

## When to Ask the User

Ask before:

- **Installing packages** — even `cmst` has a disk cost.
- **Modifying `/etc/`** — system-level change.
- **Killing any running process** — user may have unsaved work.
- **Restarting IceWM** — disrupts desktop.
- **Committing to main** — use a feature branch, open a PR.

Proceed without asking:

- Reading files under `wifi-tray/`, `~/.icewm/`, `/etc/connman/`.
- Running `diagnose.sh` or any read-only probe.
- Editing this repo's own files in `wifi-tray/`.

---

## Glossary

| Term | Meaning |
|---|---|
| antiX | Minimal Debian-based distro, sysvinit/runit, no systemd. |
| IceWM | Lightweight X11 window manager, built-in taskbar + tray. |
| connman | Intel-origin connection manager, D-Bus driven, runit-friendly. |
| connmand | The connman daemon binary. |
| cmst | Qt-based tray client for connman. |
| Supervisor | Our 15s bash loop that respawns cmst on miss. |
| XEMBED | X11 protocol for embedding one window into another; the basis of the system tray. |
| `_NET_SYSTEM_TRAY_S0` | The X11 selection that tray hosts own to advertise themselves. |
| Marker | The `# >>> wifi-tray supervisor start >>>` / `<<< end <<<` comment pair used for idempotent edits. |

---

## Reporting Format for Status Updates

When reporting back after changes, include in this order:

1. **What was changed** — file path + 1-line summary.
2. **Diagnose output before/after** — paste the relevant lines.
3. **Open issues** — anything not resolved.
4. **Next step recommendation** — what to try next, or "looks good".

Do not include: long prose preamble, apologies, restating the user's question, or emojis (unless the user asked for them).

---

*This file is the contract. If future behavior contradicts what's written here, the file is out of date — update it.*

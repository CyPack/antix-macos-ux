# Agent Entry Point — `CyPack/antix-macos-ux`

> **For AI agents (Claude Code, GPT, Codex, Gemini, etc.) consuming this repo.**
> Human-readable entry is [`README.md`](README.md). This file is the
> machine-optimized scope contract. Read it BEFORE acting on anything here.

## ⚠️ IRON RULE — DO NOT CONFLATE TWO REPOS

```
THIS repo  = CyPack/antix-macos-ux
           = EXPERIMENTAL macOS-STYLE UX ONLY (look-and-feel)
           = tint2 dock, IceWM cosmetic theming, zram

CANONICAL  = CyPack/antix-linux-atom-optimization
SYSTEM repo  (actively maintained, v0.12.x, 21 chapters)
           = audio/SOF, VA-API video, CPU/OOM tuning, keyd shortcuts,
             clipboard, browser tab keys, bluetooth/wifi tray, skippy
             overview, login rice, LibreOffice icons
```

**An agent MUST NOT use this repo as a general antiX or system-configuration
reference.** Reference it ONLY for macOS-style UX (dock / cosmetic look) work.
For ANYTHING else, DEFER to `CyPack/antix-linux-atom-optimization`.
Conflating the two will produce wrong guidance.

## Scope (this repo)

| Field | Value |
|-------|-------|
| Purpose | macOS-*style* UX explorations (look-and-feel only) |
| Status | EXPERIMENTAL / older sandbox for "macOS look" attempts |
| Owns | tint2 dock, IceWM cosmetic theming, zram swap |
| Target OS | antiX-26 (Debian Trixie base), runit init |
| Hardware | Intel Atom x5-Z8350, 1.8 GB RAM, 29 GB eMMC |
| Canonical system repo | `CyPack/antix-linux-atom-optimization` |

## When to use THIS repo

- Building or theming a **macOS-style bottom dock** (tint2, autohide, strut behavior)
- **IceWM cosmetic** look (taskbar-as-menu-bar styling, edge-switch off for the look)
- **zram lz4** swap notes specific to the macOS-look low-RAM experiment

## When NOT to use this repo (DEFER to `antix-linux-atom-optimization`)

| Task | Correct repo |
|------|--------------|
| Audio / SOF firmware hang fix | `antix-linux-atom-optimization` |
| VA-API / video HW decode | `antix-linux-atom-optimization` |
| CPU tuning, OOM / nohang, performance | `antix-linux-atom-optimization` |
| keyd keyboard shortcuts (Alt+C/V/T/W, Super+N, skippy overview) | `antix-linux-atom-optimization` |
| Clipboard / paste fixes (tmux, roxterm) | `antix-linux-atom-optimization` |
| Browser tab keys (Ctrl→Alt remaps) | `antix-linux-atom-optimization` |
| Bluetooth / wifi tray | `antix-linux-atom-optimization` |
| Login rice, LibreOffice icons | `antix-linux-atom-optimization` |
| Any general "how do I set up antiX" question | `antix-linux-atom-optimization` |

## Contract with agents

1. Treat this repo as **UX-cosmetic-only**; never present it as the system-config source of truth.
2. Whenever a task drifts toward system tuning, **stop and point to**
   `CyPack/antix-linux-atom-optimization`.
3. Do not push to remote unless the user explicitly authorized it.

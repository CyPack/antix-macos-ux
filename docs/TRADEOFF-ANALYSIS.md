# Dock Click Behavior: Launcher vs Button vs Hybrid

## Problem
tint2 Launcher (`L`) always launches a new instance. Clicking Firefox icon when Firefox is already open → opens ANOTHER Firefox window instead of focusing the existing one.

## Options Analyzed

### Option A: Current (Launcher `L`) — Keep as-is
- **macOS-like?** No — every click = new instance
- **Config:** 1 line per app
- **Risk:** Zero
- **Verdict:** Works, but not macOS behavior

### Option B: Button (`P`) + launch-or-focus wrapper script
- **macOS-like?** Yes — click = focus if running, launch if not
- **Config:** ~7 lines per app (63 lines for 9 apps)
- **Dependencies:** wmctrl + xdotool (both pre-installed on antiX)
- **Risk:** LibreOffice Writer/Calc/Impress share same WM_CLASS (`libreoffice`) — clicking Calc icon when Writer is open focuses Writer instead

**Wrapper script concept:**
```bash
#!/bin/bash
WM_CLASS="$1"; shift; COMMAND="$@"
WINID=$(wmctrl -lx | grep -i "$WM_CLASS" | head -n1 | awk '{print $1}')
if [ -n "$WINID" ]; then
    wmctrl -i -a "$WINID"  # Focus existing
else
    $COMMAND &  # Launch new
fi
```

### Option C: Hybrid `panel_items = LT` (Launcher + Taskbar)
- **macOS-like?** Half — launcher icons on left (always launch), running apps on right (click = focus)
- **Config:** Add `T` to panel_items, minimal extra config
- **Risk:** Low — no WM_CLASS matching needed, taskbar handles focus natively
- **Downside:** Two separate areas, not unified dock

## Tradeoff Table

| Criteria | Launcher (L) | Button (P) + Script | Hybrid (LT) |
|----------|-------------|--------------------:|-------------|
| Config complexity | 1 line/app | ~7 lines/app | +5 lines total |
| New app setup | Copy .desktop path | Find WM_CLASS + write block | Same as L |
| Click behavior | Always new instance | Focus or launch | L=new, T=focus |
| LibreOffice bug | N/A | YES — shared WM_CLASS | No |
| Maintenance | Zero | WM_CLASS can change | Zero |
| Dependencies | None | wmctrl + xdotool | None |

## LibreOffice WM_CLASS Problem (Button approach only)

LibreOffice Writer, Calc, and Impress all use WM_CLASS `libreoffice`. With the Button + script approach:
- Writer is open → Click Calc icon → **Focuses Writer** (WRONG!)
- No reliable way to distinguish them by WM_CLASS alone
- Window title matching is fragile (changes with document name)

## Decision

**Not implemented.** All three options have significant tradeoffs on this hardware/WM combination. The current Launcher behavior (always new instance) is the most reliable. Users can use Alt+Tab or the IceWM taskbar (at top) to switch between windows.

## References
- [tint2 Issue #356 - Dock mode request (2011, never implemented)](https://github.com/sabit/tint2/issues/356)
- [nwg-piotr/rof - Run Or Focus script](https://github.com/nwg-piotr/rof)
- [jumpapp - Run-or-raise switcher](https://github.com/mkropat/jumpapp)
- [tint2 Button documentation](https://github.com/o9000/tint2/blob/master/doc/tint2.md)

## Transparency Analysis (Abandoned)

Pseudo-transparency (`disable_transparency = 1`, `panel_background_id = 0`) was tested but showed no visible change. Root cause: wallpaper ("Solid-architecture.jpg") is dark — pseudo-transparency shows wallpaper through the panel, which looks identical to opaque dark background. Real transparency requires a compositor (picom/xcompmgr), which adds CPU overhead and stability risk on Atom x5-Z8350. **Not worth the tradeoff on this hardware.**

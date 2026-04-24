#!/usr/bin/env bash
# diagnose.sh — read-only state probe for wifi-tray.
#
# Prints a snapshot of everything relevant to diagnosing tray-icon issues.
# Pipe-friendly output — paste into bug reports.
#
# Does not modify anything. Safe to run at any time.
#
# Usage:
#   bash scripts/diagnose.sh
#   bash scripts/diagnose.sh | tee /tmp/wifi-tray-diag.log

set -u

hr() { printf -- '-- %s --\n' "$*"; }
show() { printf '%s\n' "$*"; }

show "wifi-tray diagnose — $(date -Iseconds)"
show "host: $(hostname)"
show "user: $(whoami)"
show "display: ${DISPLAY:-<unset>}"
show ""

hr "1. connman daemon state"
if command -v connmanctl >/dev/null 2>&1; then
    connmanctl state 2>&1 | sed 's/^/    /' || show "    connmanctl state: command failed"
else
    show "    connmanctl: not installed"
fi
if command -v sv >/dev/null 2>&1; then
    show "    runit status: $(sudo -n sv status connman 2>&1 | head -1 || echo 'sudo required')"
fi
show ""

hr "2. network interface state"
if command -v ip >/dev/null 2>&1; then
    ip -br link 2>/dev/null | grep -v '^lo' | sed 's/^/    /'
else
    show "    ip: not installed"
fi
show ""

hr "3. cmst process"
CMST_PIDS=$(pgrep -a cmst 2>/dev/null || true)
if [ -z "$CMST_PIDS" ]; then
    show "    cmst: NOT RUNNING"
else
    show "    $CMST_PIDS"
fi
show ""

hr "4. supervisor loop process"
SUP_PIDS=$(pgrep -af 'pgrep -x cmst' 2>/dev/null || true)
if [ -z "$SUP_PIDS" ]; then
    show "    supervisor: NOT RUNNING"
else
    show "    $SUP_PIDS" | sed 's/^/    /'
fi
show ""

hr "5. installed packages (wifi-relevant)"
if command -v dpkg >/dev/null 2>&1; then
    dpkg -l 2>/dev/null | awk '
        $2 ~ /^(cmst|connman|connman-ui|network-manager|nm-applet|wpasupplicant|runit-service-connman)$/ {
            printf "    %-30s %s\n", $2, $3
        }' || show "    dpkg query failed"
fi
show ""

hr "6. IceWM startup file"
STARTUP="$HOME/.icewm/startup"
if [ -f "$STARTUP" ]; then
    show "    path: $STARTUP ($(wc -c < "$STARTUP") bytes)"
    if grep -qF '# >>> wifi-tray supervisor start >>>' "$STARTUP"; then
        show "    marker block: PRESENT"
        awk '/# >>> wifi-tray supervisor start >>>/,/# <<< wifi-tray supervisor end <<</' "$STARTUP" | sed 's/^/        /'
    else
        show "    marker block: ABSENT (not installed via wifi-tray/install.sh)"
    fi
else
    show "    path: $STARTUP DOES NOT EXIST"
fi
show ""

hr "7. IceWM tray preferences"
for f in /etc/icewm/preferences "$HOME/.icewm/prefoverride" "$HOME/.icewm/preferences"; do
    if [ -f "$f" ]; then
        if grep -E '^(TaskBarShowTray|TaskBarAtTop|TaskBarAutoHide)' "$f" >/dev/null 2>&1; then
            show "    $f:"
            grep -E '^(TaskBarShowTray|TaskBarAtTop|TaskBarAutoHide)' "$f" | sed 's/^/        /'
        fi
    fi
done
show ""

hr "8. X11 tray selection owner"
if command -v xprop >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
    OWNER=$(xprop -root -display "$DISPLAY" _NET_SYSTEM_TRAY_S0 2>/dev/null | head -1 || echo "(query failed)")
    show "    _NET_SYSTEM_TRAY_S0 owner: $OWNER"
else
    show "    xprop unavailable or DISPLAY unset"
fi
show ""

hr "9. recent oom-killer events (last 10)"
if command -v dmesg >/dev/null 2>&1; then
    OOM=$(dmesg 2>/dev/null | grep -i 'killed process' | tail -10)
    if [ -z "$OOM" ]; then
        show "    (none)"
    else
        show "$OOM" | sed 's/^/    /'
    fi
fi
show ""

hr "10. quick verdict"
VERDICT_OK=1
if ! command -v cmst >/dev/null 2>&1; then
    show "    ❌ cmst is not installed"
    VERDICT_OK=0
fi
if [ -z "$CMST_PIDS" ]; then
    show "    ❌ cmst process not running"
    VERDICT_OK=0
fi
if [ -z "$SUP_PIDS" ]; then
    show "    ⚠  supervisor loop not running (respawn on crash will not work)"
fi
if [ -f "$STARTUP" ] && ! grep -qF '# >>> wifi-tray supervisor start >>>' "$STARTUP"; then
    show "    ⚠  supervisor not installed in ~/.icewm/startup (not persistent across sessions)"
fi
if [ "$VERDICT_OK" = 1 ] && [ -n "$SUP_PIDS" ]; then
    show "    ✅ wifi-tray is healthy"
fi

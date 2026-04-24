#!/usr/bin/env bash
# uninstall.sh — remove wifi-tray from the user's system.
#
# What it does:
#   1. Removes the supervisor block from ~/.icewm/startup (matched by markers).
#   2. Kills any running supervisor loops.
#   3. Kills the running cmst process (optional; respawn is prevented by
#      step 1 taking effect on next session; killing now stops the icon).
#
# What it does NOT do:
#   - Does not uninstall the cmst apt package. (You may want it for manual use.)
#     To remove: sudo apt-get remove cmst
#   - Does not touch connman. Wifi keeps working.
#
# Usage:
#   bash scripts/uninstall.sh
#   bash scripts/uninstall.sh --keep-cmst   # leave cmst running until logout

set -eu

STARTUP="$HOME/.icewm/startup"
MARKER_START="# >>> wifi-tray supervisor start >>>"
MARKER_END="# <<< wifi-tray supervisor end <<<"

KEEP_CMST=0
for arg in "$@"; do
    case "$arg" in
        --keep-cmst) KEEP_CMST=1 ;;
        -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }

# --- Step 1: remove block from startup ------------------------------------
say "==> Step 1/3: remove supervisor block from $STARTUP"
if [ ! -f "$STARTUP" ]; then
    say "    $STARTUP does not exist — nothing to do"
elif ! grep -qF "$MARKER_START" "$STARTUP"; then
    say "    marker not found — block is not installed"
else
    BACKUP="$STARTUP.bak.uninstall.$(date +%s)"
    say "    backing up to $BACKUP"
    cp "$STARTUP" "$BACKUP"
    say "    removing marker block"
    # Delete from MARKER_START through MARKER_END inclusive.
    sed -i "/^$(printf '%s' "$MARKER_START" | sed 's/[&/\]/\\&/g')$/,/^$(printf '%s' "$MARKER_END" | sed 's/[&/\]/\\&/g')$/d" "$STARTUP"
    # Clean up trailing blank lines left by the removal.
    sed -i -e :a -e '/^$/N;/\n$/ba' -e '/^\n*$/d' "$STARTUP"
fi

# --- Step 2: kill supervisor loops ---------------------------------------
say "==> Step 2/3: kill any running supervisor loops"
SUP_PIDS=$(pgrep -f 'pgrep -x cmst' 2>/dev/null || true)
if [ -z "$SUP_PIDS" ]; then
    say "    no supervisor running"
else
    # shellcheck disable=SC2086
    say "    killing PIDs: $SUP_PIDS"
    # shellcheck disable=SC2086
    kill $SUP_PIDS 2>/dev/null || true
fi

# --- Step 3: kill cmst (unless --keep-cmst) -------------------------------
say "==> Step 3/3: kill cmst process"
if [ "$KEEP_CMST" = 1 ]; then
    say "    --keep-cmst set: leaving cmst running (will exit on next logout)"
else
    if pgrep -x cmst >/dev/null 2>&1; then
        pkill -x cmst 2>/dev/null || true
        say "    cmst killed"
    else
        say "    cmst not running"
    fi
fi

say ""
say "Uninstall complete."
say "Note: the cmst apt package is still installed. To remove:"
say "      sudo apt-get remove cmst"

#!/usr/bin/env bash
# cmst-supervisor.sh — standalone form of the wifi-tray supervisor loop.
#
# Purpose:
#   Keep cmst (ConnMan System Tray) running. If it dies, respawn it within
#   the poll interval. Designed to be launched from ~/.icewm/startup, but
#   also runnable manually for the current X session.
#
# Usage:
#   bash cmst-supervisor.sh &          # run in background, inherits $DISPLAY
#   DISPLAY=:0 bash cmst-supervisor.sh & # when launching from an SSH shell
#
# Environment:
#   POLL_INTERVAL  — seconds between liveness checks (default: 15)
#   INITIAL_SLEEP  — seconds to wait before first launch (default: 2)
#   CMST_CMD       — command to run when cmst is missing (default: "cmst -m")
#
# Exit:
#   Never, unless killed. The loop is infinite by design.
#
# Detaching:
#   If launched from a terminal, prefer `nohup … & disown` so the supervisor
#   survives the terminal closing. ~/.icewm/startup launches are already
#   detached via the backgrounded subshell.
#
# Idempotency:
#   Do NOT run more than one instance per X session. Two supervisors race
#   to respawn cmst, causing duplicate tray icons. Check before launching:
#     pgrep -af 'pgrep -x cmst'
#
# See also:
#   wifi-tray/README.md   — overview and quick start
#   wifi-tray/GUIDE.md    — detailed technical reference
#   wifi-tray/AGENT-RULES.md — do's and don'ts for AI agents

set -u  # unset variables are errors. NOT -e: we want the loop to survive.

POLL_INTERVAL="${POLL_INTERVAL:-15}"
INITIAL_SLEEP="${INITIAL_SLEEP:-2}"
CMST_CMD="${CMST_CMD:-cmst -m}"

# Sanity: cmst must be on PATH or the loop will spin uselessly.
if ! command -v cmst >/dev/null 2>&1; then
    echo "cmst-supervisor: cmst not found on PATH. Install with: sudo apt-get install cmst" >&2
    exit 127
fi

# Initial delay so IceWM's tray selection owner is ready.
sleep "$INITIAL_SLEEP"

while :; do
    if ! pgrep -x cmst >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        $CMST_CMD &
    fi
    sleep "$POLL_INTERVAL"
done

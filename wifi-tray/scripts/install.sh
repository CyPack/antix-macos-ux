#!/usr/bin/env bash
# install.sh — idempotent installer for wifi-tray.
#
# What it does:
#   1. Verifies cmst is installed (apt-get install if missing).
#   2. Injects the supervisor block into ~/.icewm/startup (exactly once,
#      using marker comments as a grep guard).
#   3. Starts the supervisor for the current X session if DISPLAY is set.
#   4. Prints diagnostic output.
#
# Safety:
#   - Backs up ~/.icewm/startup before modification.
#   - Uses marker-bracketed insertion; re-running is a no-op.
#   - Does NOT touch /etc/ (except via apt for cmst if needed).
#   - Prompts before apt install.
#
# Usage:
#   bash scripts/install.sh
#   bash scripts/install.sh --no-prompt   # skip apt confirmation (for automation)
#   bash scripts/install.sh --dry-run     # show what would be done, do nothing

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SNIPPET="$REPO_DIR/configs/icewm-startup-snippet"
SUPERVISOR="$REPO_DIR/configs/cmst-supervisor.sh"
STARTUP="$HOME/.icewm/startup"
MARKER_START="# >>> wifi-tray supervisor start >>>"
MARKER_END="# <<< wifi-tray supervisor end <<<"

DRY_RUN=0
NO_PROMPT=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --no-prompt) NO_PROMPT=1 ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }
run() {
    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY-RUN: $*"
    else
        eval "$@"
    fi
}

# --- Step 1: verify cmst --------------------------------------------------
say "==> Step 1/4: verify cmst is installed"
if command -v cmst >/dev/null 2>&1; then
    say "    cmst present: $(cmst --version 2>/dev/null | head -1 || echo 'installed')"
else
    say "    cmst not installed."
    if [ "$NO_PROMPT" = 1 ]; then
        REPLY=y
    else
        printf "    Install via apt-get? [Y/n] "
        read -r REPLY
        REPLY="${REPLY:-y}"
    fi
    case "$REPLY" in
        y|Y|yes|YES)
            run "sudo apt-get update && sudo apt-get install -y cmst"
            ;;
        *)
            say "    Skipping install. You must install cmst before the supervisor can work."
            exit 1
            ;;
    esac
fi

# --- Step 2: ensure ~/.icewm/startup exists and is executable -------------
say "==> Step 2/4: prepare ~/.icewm/startup"
if [ ! -f "$STARTUP" ]; then
    say "    creating $STARTUP"
    run "mkdir -p '$HOME/.icewm'"
    run "printf '%s\n' '#!/bin/bash' > '$STARTUP'"
    run "chmod 755 '$STARTUP'"
else
    say "    $STARTUP exists ($(wc -c < "$STARTUP") bytes)"
fi

# --- Step 3: inject the supervisor block if not already present ----------
say "==> Step 3/4: inject supervisor block (idempotent)"
if grep -qF "$MARKER_START" "$STARTUP" 2>/dev/null; then
    say "    marker already present — nothing to do (safe re-run)"
else
    BACKUP="$STARTUP.bak.$(date +%s)"
    say "    backing up to $BACKUP"
    run "cp '$STARTUP' '$BACKUP'"
    say "    appending snippet from $SNIPPET"
    if [ "$DRY_RUN" = 1 ]; then
        echo "DRY-RUN: cat '$SNIPPET' >> '$STARTUP'"
    else
        printf '\n' >> "$STARTUP"
        cat "$SNIPPET" >> "$STARTUP"
    fi
fi

# --- Step 4: start supervisor for current session -------------------------
say "==> Step 4/4: start supervisor for current X session"
if [ -z "${DISPLAY:-}" ]; then
    say "    DISPLAY not set — skipping live launch (will start on next X login)"
else
    if pgrep -af 'pgrep -x cmst' >/dev/null 2>&1; then
        say "    supervisor already running — not starting a second one"
    else
        say "    launching supervisor detached"
        if [ "$DRY_RUN" = 1 ]; then
            echo "DRY-RUN: nohup bash '$SUPERVISOR' >/tmp/cmst-supervisor.log 2>&1 & disown"
        else
            # shellcheck disable=SC2086
            nohup bash "$SUPERVISOR" >/tmp/cmst-supervisor.log 2>&1 & disown
        fi
        sleep 3  # give the supervisor's initial sleep + first iteration
    fi
fi

# --- Diagnostics ----------------------------------------------------------
say ""
say "==> Final state"
say "    connman state:    $(connmanctl state 2>/dev/null | awk -F= '/State/{gsub(/ /,"");print $2}')"
say "    cmst process:     $(pgrep -a cmst 2>/dev/null || echo '(not running)')"
say "    supervisor loop:  $(pgrep -af 'pgrep -x cmst' 2>/dev/null | head -1 || echo '(not running)')"
say ""
say "Install complete. The wifi tray icon should appear in the bottom-right."
say "If not, run: bash $REPO_DIR/scripts/diagnose.sh"

#!/usr/bin/env bash
# Remove an installed FloatText.app from ~/Applications (default) or
# /Applications (with --system, requires sudo).
# Optionally also delete persisted UserDefaults via --purge.
#
# Usage:
#   scripts/uninstall.sh                    # remove from ~/Applications, keep prefs
#   scripts/uninstall.sh --system           # remove from /Applications (sudo)
#   scripts/uninstall.sh --purge            # also delete UserDefaults
#   scripts/uninstall.sh --system --purge   # both

set -euo pipefail

SYSTEM=0
PURGE=0
for arg in "$@"; do
    case "$arg" in
        --system) SYSTEM=1 ;;
        --purge) PURGE=1 ;;
        *) echo "Unknown flag: $arg" >&2; exit 2 ;;
    esac
done

DEST="$HOME/Applications"
if [[ $SYSTEM -eq 1 ]]; then
    DEST="/Applications"
fi

APP_PATH="$DEST/FloatText.app"

echo "==> Stopping any running FloatText ..."
killall FloatText 2>/dev/null || true

if [[ -d "$APP_PATH" ]]; then
    echo "==> Removing $APP_PATH"
    if [[ $SYSTEM -eq 1 ]]; then
        sudo rm -rf "$APP_PATH"
    else
        rm -rf "$APP_PATH"
    fi
else
    echo "==> No app at $APP_PATH (already uninstalled)"
fi

if [[ $PURGE -eq 1 ]]; then
    echo "==> Deleting UserDefaults (com.floattext.FloatText)"
    defaults delete com.floattext.FloatText 2>/dev/null || echo "    (no defaults domain to delete)"
fi

echo ""
echo "Uninstall complete."
if [[ $PURGE -eq 0 ]]; then
    echo "Tip: rerun with --purge to also remove saved text / window position / settings."
fi

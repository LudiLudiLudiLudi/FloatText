#!/usr/bin/env bash
# Build FloatText in Release configuration and copy the .app to ~/Applications
# (default) or /Applications (with --system, requires sudo).
#
# Usage:
#   scripts/install.sh            # install to ~/Applications
#   scripts/install.sh --system   # install to /Applications (sudo)
#
# Idempotent: a previous install at the target path is replaced.

set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"

DEST="$HOME/Applications"
if [[ "${1:-}" == "--system" ]]; then
    DEST="/Applications"
fi

echo "==> Building FloatText (Release) ..."
xcodebuild \
    -project FloatText.xcodeproj \
    -scheme FloatText \
    -configuration Release \
    -derivedDataPath build \
    build \
    > /tmp/floattext-install.log 2>&1 \
    || { echo "Build failed. Tail of log:"; tail -30 /tmp/floattext-install.log; exit 1; }

APP_SRC="$PROJECT_ROOT/build/Build/Products/Release/FloatText.app"
if [[ ! -d "$APP_SRC" ]]; then
    echo "Error: expected .app not found at $APP_SRC"
    exit 1
fi

mkdir -p "$DEST"

echo "==> Stopping any running FloatText ..."
killall FloatText 2>/dev/null || true

APP_DEST="$DEST/FloatText.app"
echo "==> Installing to $APP_DEST"

if [[ "$DEST" == "/Applications" ]]; then
    sudo rm -rf "$APP_DEST"
    sudo cp -R "$APP_SRC" "$APP_DEST"
else
    rm -rf "$APP_DEST"
    cp -R "$APP_SRC" "$APP_DEST"
fi

echo "==> Registering with LaunchServices ..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_DEST" >/dev/null 2>&1 || true

echo ""
echo "Installed. Launch from:"
echo "  open \"$APP_DEST\""
echo ""
echo "To uninstall: scripts/uninstall.sh${1:+ --system}"

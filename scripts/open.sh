#!/usr/bin/env bash
# Force-open in Xcode. The bare `open` command honors the user's default app
# for .xcodeproj bundles, which on some systems (Cursor, AppCode, etc.) is
# NOT Xcode. -b com.apple.dt.Xcode bypasses that.
set -e
cd "$(dirname "$0")/.."
open -b com.apple.dt.Xcode FloatText.xcodeproj

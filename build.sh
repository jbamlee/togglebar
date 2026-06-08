#!/bin/zsh
# Build ToggleKit + CLI + menu bar app, then bundle the app.
# Installation is owned by install.sh so all choices are collected before side effects.
set -euo pipefail
DIR=${0:A:h}
cd "$DIR"

echo "▶ swift build -c release"
swift build -c release

APP="$DIR/ToggleBar.app"
echo "▶ bundling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$DIR/.build/release/ToggleBarApp" "$APP/Contents/MacOS/ToggleBar"
cp "$DIR/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo ""
echo "✅ App: $APP"
echo "✅ CLI: $DIR/.build/release/togglebar"

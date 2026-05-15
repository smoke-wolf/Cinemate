#!/bin/bash
set -e

cd "$(dirname "$0")/Cinemate"

echo "Building Cinemate..."
swift build -c debug 2>&1

APP_DIR="$HOME/Desktop/Cinemate.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp .build/debug/Cinemate "$MACOS/Cinemate"

# Copy app icon
ICON_SRC="$(dirname "$0")/icon/Cinemate.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$RESOURCES/Cinemate.icns"
fi

cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Cinemate</string>
    <key>CFBundleIdentifier</key>
    <string>com.maliq.cinemate</string>
    <key>CFBundleName</key>
    <string>Cinemate</string>
    <key>CFBundleDisplayName</key>
    <string>Cinemate</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>CFBundleIconFile</key>
    <string>Cinemate</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
</dict>
</plist>
PLIST

echo ""
echo "Built: $APP_DIR"
echo "Run:   open '$APP_DIR'"

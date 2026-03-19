#!/bin/bash
set -e

APP_NAME="Yapper"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="0.3.2"
DIST_DIR="$PROJECT_DIR/dist"
DMG_DIR="$DIST_DIR/dmg-staging"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
BG_IMG="$DIST_DIR/dmg-background.tiff"

# Architecture
ARCH="${1:-$(uname -m)}"
if [ "$ARCH" = "arm64" ]; then
    ARCH_LABEL="apple-silicon"
    SWIFT_ARCH="arm64"
elif [ "$ARCH" = "x86_64" ]; then
    ARCH_LABEL="intel"
    SWIFT_ARCH="x86_64"
else
    ARCH_LABEL="$ARCH"
    SWIFT_ARCH="$ARCH"
fi

DMG_TEMP="$DIST_DIR/${APP_NAME}-temp.dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}-${ARCH_LABEL}.dmg"

echo "🔨 Building $APP_NAME v$VERSION for $ARCH_LABEL..."

# Step 1: Build the app
bash "$PROJECT_DIR/build.sh"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found"
    exit 1
fi

echo "📀 Creating styled DMG..."

# Step 2: Create staging directory
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR/.background"

# Copy app and background
cp -r "$APP_BUNDLE" "$DMG_DIR/"
cp "$BG_IMG" "$DMG_DIR/.background/background.tiff"
ln -s /Applications "$DMG_DIR/Applications"

# Step 3: Create temporary read-write DMG
rm -f "$DMG_TEMP"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    -size 50m \
    "$DMG_TEMP"

# Step 4: Mount and style
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | tail -1 | awk '{print $3}')

# Wait for mount
sleep 2

echo "🎨 Styling DMG window..."

# Apply Finder window settings via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 700, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.tiff"
        -- Position icons: app at top center, Applications at bottom center
        set position of item "$APP_NAME.app" to {300, 180}
        set position of item "Applications" to {300, 360}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Ensure .background is hidden
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || true

sync

# Step 5: Unmount
hdiutil detach "$MOUNT_DIR" -quiet

# Step 6: Convert to compressed read-only DMG
rm -f "$DMG_PATH"
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_TEMP"

# Clean up staging
rm -rf "$DMG_DIR"

# Results
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo ""
echo "✅ DMG created successfully!"
echo "📍 Location: $DMG_PATH"
echo "📏 Size: $DMG_SIZE"
echo "🏗️ Architecture: $ARCH_LABEL"

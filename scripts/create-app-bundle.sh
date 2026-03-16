#!/bin/bash

# Create macOS app bundle from built binary

set -e

CONFIG="${1:-Debug}"
BINARY_PATH=".build/${CONFIG}/Yapper"
BUNDLE_PATH="build/Yapper.app"

echo "Creating app bundle at $BUNDLE_PATH..."

# Create bundle structure
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
mkdir -p "$BUNDLE_PATH/Contents/Resources"

# Copy binary
cp "$BINARY_PATH" "$BUNDLE_PATH/Contents/MacOS/Yapper"
chmod +x "$BUNDLE_PATH/Contents/MacOS/Yapper"

# Copy Info.plist
cp "Sources/Yapper/Resources/Info.plist" "$BUNDLE_PATH/Contents/Info.plist"

# Copy icon if exists
if [ -f "Sources/Yapper/Resources/AppIcon.icns" ]; then
    cp "Sources/Yapper/Resources/AppIcon.icns" "$BUNDLE_PATH/Contents/Resources/"
fi

echo "✓ App bundle created successfully!"
echo "  Location: $BUNDLE_PATH"
echo ""
echo "To run: open $BUNDLE_PATH"

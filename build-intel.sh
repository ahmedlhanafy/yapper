#!/bin/bash
set -e

APP_NAME="Yapper"
BUNDLE_ID="com.yapper.app"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/x86_64-apple-macosx/release"
APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
WHISPER_BUILD="$PROJECT_DIR/Vendor/whisper.cpp/build-x86"
if [ "${YAPPER_DIST:-0}" = "1" ]; then
    SIGN_IDENTITY="-"
else
    SIGN_IDENTITY="9985842FC8FB705467E2FBEC63F591057CB2F9D6"
fi

echo "🔨 Building $APP_NAME for Intel (x86_64)..."

# Swap whisper build to x86 version
WHISPER_ARM="$PROJECT_DIR/Vendor/whisper.cpp/build"
WHISPER_ARM_BAK="$PROJECT_DIR/Vendor/whisper.cpp/build-arm64"
mv "$WHISPER_ARM" "$WHISPER_ARM_BAK"
ln -s "$WHISPER_BUILD" "$WHISPER_ARM"

# Build for x86_64
swift build -c release --arch x86_64

# Restore arm64 build
rm "$WHISPER_ARM"
mv "$WHISPER_ARM_BAK" "$WHISPER_ARM"

# Create app bundle
echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

echo "📋 Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

echo "📋 Copying Info.plist..."
cp "$PROJECT_DIR/Sources/Yapper/Resources/Info.plist" "$APP_BUNDLE/Contents/"

echo "🎨 Copying app icon..."
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "📚 Copying Intel libraries..."
DYLIBS=(
    "$WHISPER_BUILD/src/libwhisper.1.dylib"
    "$WHISPER_BUILD/ggml/src/libggml.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-base.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-cpu.0.dylib"
)

for dylib in "${DYLIBS[@]}"; do
    if [ -f "$dylib" ]; then
        cp -L "$dylib" "$APP_BUNDLE/Contents/Frameworks/"
    fi
done

# Copy Sparkle framework
echo "📚 Copying Sparkle framework..."
SPARKLE_FRAMEWORK=$(find "$PROJECT_DIR/.build/artifacts" -name "Sparkle.framework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    echo "  Copied from: $SPARKLE_FRAMEWORK"
else
    echo "⚠️ Sparkle.framework not found in .build/artifacts - update checking will not work"
fi

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "🔧 Fixing library paths..."
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE" 2>/dev/null || true

install_name_tool -change "@rpath/libwhisper.1.dylib" "@executable_path/../Frameworks/libwhisper.1.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml.0.dylib" "@executable_path/../Frameworks/libggml.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$EXECUTABLE"

echo "🔧 Fixing inter-library dependencies..."
if [ -f "$FRAMEWORKS_DIR/libwhisper.1.dylib" ]; then
    install_name_tool -change "@rpath/libggml.0.dylib" "@executable_path/../Frameworks/libggml.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libwhisper.1.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
fi

if [ -f "$FRAMEWORKS_DIR/libggml.0.dylib" ]; then
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
    install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libggml.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
fi

if [ -f "$FRAMEWORKS_DIR/libggml-base.0.dylib" ]; then
    install_name_tool -id "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml-base.0.dylib"
fi

if [ -f "$FRAMEWORKS_DIR/libggml-cpu.0.dylib" ]; then
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml-cpu.0.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libggml-cpu.0.dylib"
fi

echo "🔐 Code signing..."
for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$dylib" ]; then
        codesign --force --sign "$SIGN_IDENTITY" "$dylib"
    fi
done

# Sign Sparkle framework components (inner-most first)
if [ -d "$FRAMEWORKS_DIR/Sparkle.framework" ]; then
    echo "🔐 Signing Sparkle framework..."
    SPARKLE_DIR="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
    for component in \
        "$SPARKLE_DIR/XPCServices/Installer.xpc" \
        "$SPARKLE_DIR/XPCServices/Downloader.xpc" \
        "$SPARKLE_DIR/Updater.app" \
        "$SPARKLE_DIR/Autoupdate"; do
        if [ -e "$component" ]; then
            codesign --force --sign "$SIGN_IDENTITY" "$component"
        fi
    done
    codesign --force --sign "$SIGN_IDENTITY" "$FRAMEWORKS_DIR/Sparkle.framework"
fi

codesign --force --sign "$SIGN_IDENTITY" \
    --identifier "$BUNDLE_ID" \
    --entitlements "$PROJECT_DIR/Yapper.entitlements" \
    --deep \
    "$APP_BUNDLE"

echo ""
echo "✅ Intel build complete!"
echo "📍 App bundle: $APP_BUNDLE"

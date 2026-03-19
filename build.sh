#!/bin/bash
set -e

# Configuration
APP_NAME="Yapper"
BUNDLE_ID="com.yapper.app"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
WHISPER_BUILD="$PROJECT_DIR/Vendor/whisper.cpp/build"

echo "🔨 Building $APP_NAME for release..."

# Step 1: Build release
swift build -c release

# Step 2: Create app bundle structure
echo "📦 Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# Step 3: Copy executable
echo "📋 Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Step 4: Copy Info.plist
echo "📋 Copying Info.plist..."
cp "$PROJECT_DIR/Sources/Yapper/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Step 5: Copy app icon
echo "🎨 Copying app icon..."
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Step 6: Copy dylibs to Frameworks
echo "📚 Copying libraries..."
DYLIBS=(
    "$WHISPER_BUILD/src/libwhisper.1.dylib"
    "$WHISPER_BUILD/ggml/src/libggml.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-base.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-cpu.0.dylib"
    "$WHISPER_BUILD/ggml/src/ggml-blas/libggml-blas.0.dylib"
    "$WHISPER_BUILD/ggml/src/ggml-metal/libggml-metal.0.dylib"
)

for dylib in "${DYLIBS[@]}"; do
    if [ -f "$dylib" ]; then
        # Follow symlinks and copy actual file
        cp -L "$dylib" "$APP_BUNDLE/Contents/Frameworks/"
    fi
done

# Step 6b: Copy Sparkle framework
echo "📚 Copying Sparkle framework..."
SPARKLE_FRAMEWORK=$(find "$PROJECT_DIR/.build/artifacts" -name "Sparkle.framework" -type d 2>/dev/null | head -1)
if [ -n "$SPARKLE_FRAMEWORK" ]; then
    cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
    echo "  Copied from: $SPARKLE_FRAMEWORK"
else
    echo "⚠️ Sparkle.framework not found in .build/artifacts - update checking will not work"
fi

# Step 7: Copy Metal shader
echo "⚙️ Copying Metal shader..."
if [ -f "$WHISPER_BUILD/bin/ggml-metal.metal" ]; then
    cp "$WHISPER_BUILD/bin/ggml-metal.metal" "$APP_BUNDLE/Contents/Resources/"
fi

# Step 8: Fix library paths in executable
echo "🔧 Fixing library paths..."
EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Update rpaths in executable to look in Frameworks folder
install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE" 2>/dev/null || true

# Remove hardcoded local rpaths that don't exist on other machines
otool -l "$EXECUTABLE" | grep -A2 LC_RPATH | grep "path " | sed 's/.*path \(.*\) (offset.*/\1/' | while read -r rpath; do
    case "$rpath" in
        @*) ;;                    # keep @executable_path, @loader_path
        /usr/lib/*) ;;            # keep system paths
        /System/*) ;;             # keep system paths
        /Applications/Xcode*) ;;  # keep Xcode toolchain paths
        *)  install_name_tool -delete_rpath "$rpath" "$EXECUTABLE" 2>/dev/null || true
            echo "  Removed rpath: $rpath"
            ;;
    esac
done

# Fix each library reference in the executable
install_name_tool -change "@rpath/libwhisper.1.dylib" "@executable_path/../Frameworks/libwhisper.1.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml.0.dylib" "@executable_path/../Frameworks/libggml.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-metal.0.dylib" "@executable_path/../Frameworks/libggml-metal.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-blas.0.dylib" "@executable_path/../Frameworks/libggml-blas.0.dylib" "$EXECUTABLE"

# Step 9: Fix ALL inter-library @rpath references
echo "🔧 Fixing inter-library dependencies..."
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

# Fix every @rpath reference in every bundled dylib
KNOWN_LIBS=("libwhisper.1.dylib" "libggml.0.dylib" "libggml-base.0.dylib" "libggml-cpu.0.dylib" "libggml-blas.0.dylib" "libggml-metal.0.dylib")

for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
    [ -f "$dylib" ] || continue
    dylib_name=$(basename "$dylib")

    # Set install name
    install_name_tool -id "@executable_path/../Frameworks/$dylib_name" "$dylib" 2>/dev/null || true

    # Fix all @rpath references to point to Frameworks
    for lib in "${KNOWN_LIBS[@]}"; do
        install_name_tool -change "@rpath/$lib" "@executable_path/../Frameworks/$lib" "$dylib" 2>/dev/null || true
    done

    # Also strip any hardcoded local rpaths from dylibs
    otool -l "$dylib" 2>/dev/null | grep -A2 LC_RPATH | grep "path " | sed 's/.*path \(.*\) (offset.*/\1/' | while read -r rpath; do
        case "$rpath" in
            @*|/usr/lib/*|/System/*) ;;
            *) install_name_tool -delete_rpath "$rpath" "$dylib" 2>/dev/null || true ;;
        esac
    done
done

echo "  Fixed $(ls "$FRAMEWORKS_DIR"/*.dylib | wc -l | tr -d ' ') libraries"

# Legacy individual fixes (keep for safety)
if [ -f "$FRAMEWORKS_DIR/libggml-cpu.0.dylib" ]; then
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml-cpu.0.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libggml-cpu.0.dylib"
fi

# Fix libggml-metal dependencies
if [ -f "$FRAMEWORKS_DIR/libggml-metal.0.dylib" ]; then
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml-metal.0.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libggml-metal.0.dylib" "$FRAMEWORKS_DIR/libggml-metal.0.dylib"
fi

# Step 10: Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Step 11: Code sign the app
# Use local cert for dev, ad-hoc for distribution
if [ "${YAPPER_DIST:-0}" = "1" ]; then
    SIGN_IDENTITY="-"
    echo "🔐 Code signing (ad-hoc, for distribution)..."
else
    SIGN_IDENTITY="9985842FC8FB705467E2FBEC63F591057CB2F9D6"
    echo "🔐 Code signing (local dev cert)..."
fi

# Sign frameworks individually (do NOT use --deep on the app)
for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$dylib" ]; then
        codesign --force --sign "$SIGN_IDENTITY" --timestamp "$dylib"
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
            codesign --force --sign "$SIGN_IDENTITY" --timestamp "$component"
        fi
    done
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$FRAMEWORKS_DIR/Sparkle.framework"
fi

# Sign the app bundle (without --deep to avoid corrupting inner signatures)
codesign --force --sign "$SIGN_IDENTITY" \
    --identifier "com.yapper.app" \
    --entitlements "$PROJECT_DIR/Yapper.entitlements" \
    --timestamp \
    "$APP_BUNDLE"

echo ""
echo "✅ Build complete!"
echo "📍 App bundle: $APP_BUNDLE"
echo ""
echo "To install, run:"
echo "  cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "Or open the dist folder:"
echo "  open \"$PROJECT_DIR/dist\""

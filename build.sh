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

# Step 5: Compile and copy Assets.xcassets
echo "🎨 Compiling assets..."
xcrun actool "$PROJECT_DIR/Sources/Yapper/Resources/Assets.xcassets" \
    --compile "$APP_BUNDLE/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$APP_BUNDLE/Contents/Resources/Assets.plist" \
    2>/dev/null || echo "Warning: actool had issues, continuing..."

# Step 6: Copy dylibs to Frameworks
echo "📚 Copying libraries..."
DYLIBS=(
    "$WHISPER_BUILD/src/libwhisper.1.dylib"
    "$WHISPER_BUILD/ggml/src/libggml.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-base.0.dylib"
    "$WHISPER_BUILD/ggml/src/libggml-cpu.0.dylib"
    "$WHISPER_BUILD/ggml/src/ggml-metal/libggml-metal.0.dylib"
)

for dylib in "${DYLIBS[@]}"; do
    if [ -f "$dylib" ]; then
        # Follow symlinks and copy actual file
        cp -L "$dylib" "$APP_BUNDLE/Contents/Frameworks/"
    fi
done

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

# Fix each library reference in the executable
install_name_tool -change "@rpath/libwhisper.1.dylib" "@executable_path/../Frameworks/libwhisper.1.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml.0.dylib" "@executable_path/../Frameworks/libggml.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$EXECUTABLE"
install_name_tool -change "@rpath/libggml-metal.0.dylib" "@executable_path/../Frameworks/libggml-metal.0.dylib" "$EXECUTABLE"

# Step 9: Fix inter-library dependencies
echo "🔧 Fixing inter-library dependencies..."
FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"

# Fix libwhisper dependencies
if [ -f "$FRAMEWORKS_DIR/libwhisper.1.dylib" ]; then
    install_name_tool -change "@rpath/libggml.0.dylib" "@executable_path/../Frameworks/libggml.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -change "@rpath/libggml-metal.0.dylib" "@executable_path/../Frameworks/libggml-metal.0.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libwhisper.1.dylib" "$FRAMEWORKS_DIR/libwhisper.1.dylib"
fi

# Fix libggml dependencies
if [ -f "$FRAMEWORKS_DIR/libggml.0.dylib" ]; then
    install_name_tool -change "@rpath/libggml-base.0.dylib" "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
    install_name_tool -change "@rpath/libggml-cpu.0.dylib" "@executable_path/../Frameworks/libggml-cpu.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
    install_name_tool -change "@rpath/libggml-metal.0.dylib" "@executable_path/../Frameworks/libggml-metal.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
    install_name_tool -id "@executable_path/../Frameworks/libggml.0.dylib" "$FRAMEWORKS_DIR/libggml.0.dylib"
fi

# Fix libggml-base
if [ -f "$FRAMEWORKS_DIR/libggml-base.0.dylib" ]; then
    install_name_tool -id "@executable_path/../Frameworks/libggml-base.0.dylib" "$FRAMEWORKS_DIR/libggml-base.0.dylib"
fi

# Fix libggml-cpu dependencies
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

# Step 11: Code sign the app (ad-hoc signing for local use)
echo "🔐 Code signing..."

# Sign frameworks first
for dylib in "$FRAMEWORKS_DIR"/*.dylib; do
    if [ -f "$dylib" ]; then
        codesign --force --sign - "$dylib"
    fi
done

# Sign the main app with entitlements
codesign --force --sign - \
    --entitlements "$PROJECT_DIR/Yapper.entitlements" \
    --deep \
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

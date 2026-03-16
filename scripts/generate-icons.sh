#!/bin/bash

# Generate Yapper app icons from SVG
# Creates all required PNG sizes for macOS app icon

set -e

echo "🎨 Generating Yapper App Icons..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SVG_FILE="yapper-icon.svg"
OUTPUT_DIR="Sources/Yapper/Resources/Assets.xcassets/AppIcon.appiconset"

# Check if SVG exists
if [ ! -f "$SVG_FILE" ]; then
    echo -e "${RED}❌ yapper-icon.svg not found${NC}"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# macOS app icon sizes (width x height)
sizes=(16 32 64 128 256 512 1024)

echo "Generating icon sizes..."

for size in "${sizes[@]}"; do
    # 1x resolution
    echo -n "  ${size}x${size} ... "
    magick -background none "$SVG_FILE" -resize ${size}x${size} "$OUTPUT_DIR/icon_${size}x${size}.png" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    # 2x resolution (Retina)
    if [ $size -lt 1024 ]; then
        echo -n "  ${size}x${size}@2x ... "
        magick -background none "$SVG_FILE" -resize $((size*2))x$((size*2)) "$OUTPUT_DIR/icon_${size}x${size}@2x.png" 2>/dev/null
        echo -e "${GREEN}✓${NC}"
    fi
done

# Generate Contents.json for Xcode
echo "📋 Creating Contents.json..."

cat > "$OUTPUT_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16.png",
      "scale" : "1x"
    },
    {
      "size" : "16x16",
      "idiom" : "mac",
      "filename" : "icon_16x16@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32.png",
      "scale" : "1x"
    },
    {
      "size" : "32x32",
      "idiom" : "mac",
      "filename" : "icon_32x32@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128.png",
      "scale" : "1x"
    },
    {
      "size" : "128x128",
      "idiom" : "mac",
      "filename" : "icon_128x128@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256.png",
      "scale" : "1x"
    },
    {
      "size" : "256x256",
      "idiom" : "mac",
      "filename" : "icon_256x256@2x.png",
      "scale" : "2x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512.png",
      "scale" : "1x"
    },
    {
      "size" : "512x512",
      "idiom" : "mac",
      "filename" : "icon_512x512@2x.png",
      "scale" : "2x"
    }
  ],
  "info" : {
    "version" : 1,
    "author" : "xcode"
  }
}
EOF

echo -e "${GREEN}✓ Created Contents.json${NC}"

# Count generated files
icon_count=$(ls -1 "$OUTPUT_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo -e "${GREEN}✅ Icon generation complete!${NC}"
echo ""
echo "Generated $icon_count PNG files in:"
echo "  $OUTPUT_DIR"
echo ""
echo "Icon sizes:"
ls -lh "$OUTPUT_DIR"/*.png | awk '{print "  " $9 " - " $5}'

echo ""
echo "Next steps:"
echo "  1. Rebuild Yapper: swift build"
echo "  2. Create app bundle: ./scripts/create-app-bundle.sh"
echo "  3. The app will now have the Yapper icon!"

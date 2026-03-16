#!/bin/bash

# Setup script for whisper.cpp integration
# This script downloads, builds, and links whisper.cpp for Yapper

set -e  # Exit on error

echo "🎙️ Setting up Whisper.cpp for Yapper..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

VENDOR_DIR="Vendor"
WHISPER_DIR="$VENDOR_DIR/whisper.cpp"
CWHISPER_DIR="$VENDOR_DIR/CWhisper"

# Check if whisper.cpp already exists
if [ -d "$WHISPER_DIR" ]; then
    echo -e "${YELLOW}whisper.cpp directory already exists${NC}"
    read -p "Remove and re-clone? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing whisper.cpp..."
        rm -rf "$WHISPER_DIR"
    else
        echo "Skipping clone"
    fi
fi

# Clone whisper.cpp if needed
if [ ! -d "$WHISPER_DIR" ]; then
    echo "📦 Cloning whisper.cpp..."
    mkdir -p "$VENDOR_DIR"
    cd "$VENDOR_DIR"
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd ../
    echo -e "${GREEN}✓ Cloned whisper.cpp${NC}"
fi

# Build whisper.cpp with CMake
echo "🔨 Building whisper.cpp..."
cd "$WHISPER_DIR"

# Configure with CMake
echo "Configuring CMake build..."
cmake -B build

# Build library
echo "Building libraries..."
cmake --build build -j --config Release

# Check if libraries were built successfully
if [ ! -f "build/src/libwhisper.dylib" ]; then
    echo -e "${RED}❌ Failed to build libwhisper.dylib${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Built libwhisper.dylib and ggml libraries${NC}"

cd ../../

# Copy headers to CWhisper module
echo "📋 Copying headers..."
if [ -f "$WHISPER_DIR/include/whisper.h" ]; then
    cp "$WHISPER_DIR/include/whisper.h" "$CWHISPER_DIR/whisper.h"
    echo -e "${GREEN}✓ Copied whisper.h${NC}"
else
    echo -e "${RED}❌ whisper.h not found${NC}"
    exit 1
fi

# Copy all ggml headers
if [ -d "$WHISPER_DIR/ggml/include" ]; then
    cp "$WHISPER_DIR/ggml/include"/*.h "$CWHISPER_DIR/" 2>/dev/null
    echo -e "${GREEN}✓ Copied ggml headers ($(ls -1 $WHISPER_DIR/ggml/include/*.h | wc -l | tr -d ' ') files)${NC}"
else
    echo -e "${YELLOW}⚠️  ggml headers not found (may cause build issues)${NC}"
fi

# Download a model for testing
echo ""
echo "📥 Downloading Whisper base.en model for testing..."
cd "$WHISPER_DIR"

if [ ! -f "models/ggml-base.en.bin" ]; then
    bash ./models/download-ggml-model.sh base.en
    echo -e "${GREEN}✓ Downloaded ggml-base.en.bin (~141 MB)${NC}"
else
    echo -e "${YELLOW}ggml-base.en.bin already exists${NC}"
fi

cd ../../

# Copy model to Yapper models directory
MODELS_DIR="$HOME/Documents/Yapper/Models"
mkdir -p "$MODELS_DIR"

if [ -f "$WHISPER_DIR/models/ggml-base.en.bin" ]; then
    echo "📋 Copying model to Yapper Models directory..."
    cp "$WHISPER_DIR/models/ggml-base.en.bin" "$MODELS_DIR/"
    echo -e "${GREEN}✓ Copied model to $MODELS_DIR${NC}"
fi

echo ""
echo -e "${GREEN}✅ Whisper.cpp setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Build Yapper: swift build"
echo "  2. Run Yapper: .build/debug/Yapper"
echo "  3. The app will now use real Whisper transcription!"
echo ""
echo "Model location: $MODELS_DIR/ggml-base.en.bin"
echo "Library location: $(pwd)/$WHISPER_DIR/build/src/libwhisper.dylib"

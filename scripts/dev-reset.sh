#!/bin/bash
# Yapper Development Reset Script
# Resets app to clean state for testing

set -e

echo "🔄 Yapper Development Reset"
echo "=============================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Confirm action
echo -e "${YELLOW}⚠️  WARNING: This will delete all Yapper data!${NC}"
echo ""
echo "This will remove:"
echo "  • Settings and configuration"
echo "  • All recorded sessions"
echo "  • Audio files"
echo "  • History database"
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

echo ""
echo "🗑️  Removing Yapper data..."

# Remove Yapper directory
YAPPER_DIR="$HOME/Documents/Yapper"
if [ -d "$YAPPER_DIR" ]; then
    rm -rf "$YAPPER_DIR"
    echo "✅ Removed $YAPPER_DIR"
else
    echo "ℹ️  No Yapper directory found"
fi

# Remove API keys from Keychain (optional)
echo ""
read -p "Remove API keys from Keychain? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    security delete-generic-password -s "Yapper.APIKey.OpenAI" 2>/dev/null && echo "✅ Removed OpenAI key" || echo "ℹ️  No OpenAI key found"
    security delete-generic-password -s "Yapper.APIKey.Anthropic" 2>/dev/null && echo "✅ Removed Anthropic key" || echo "ℹ️  No Anthropic key found"
fi

# Kill running instance
echo ""
echo "🔪 Stopping Yapper..."
pkill -x "Yapper" 2>/dev/null && echo "✅ Stopped Yapper" || echo "ℹ️  Yapper not running"

# Clean build artifacts (optional)
echo ""
read -p "Clean build artifacts? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$(dirname "$0")/.."
    if [ -d ".build" ]; then
        rm -rf .build
        echo "✅ Removed .build directory"
    fi
fi

echo ""
echo -e "${GREEN}✅ Reset complete!${NC}"
echo ""
echo "Yapper is now in a clean state."
echo "Run 'swift build && .build/debug/Yapper' to start fresh."

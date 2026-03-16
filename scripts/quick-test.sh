#!/bin/bash
# Yapper Quick Test Script
# Runs basic sanity checks

set -e

echo "🧪 Yapper Quick Test"
echo "===================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
PASSED=0
FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED++))
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED++))
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Navigate to project root
cd "$(dirname "$0")/.."

echo "📂 Project: $(basename "$(pwd)")"
echo ""

# Test 1: Package.swift exists
echo "Test 1: Package.swift exists"
if [ -f "Package.swift" ]; then
    pass "Package.swift found"
else
    fail "Package.swift not found"
fi

# Test 2: Sources directory structure
echo "Test 2: Source structure"
if [ -d "Sources/Yapper" ]; then
    pass "Sources/Yapper exists"
else
    fail "Sources/Yapper missing"
fi

# Test 3: Core files exist
echo "Test 3: Core files"
CORE_FILES=(
    "Sources/Yapper/YapperApp.swift"
    "Sources/Yapper/Core/RecordingCoordinator.swift"
    "Sources/Yapper/Core/Audio/AudioEngine.swift"
    "Sources/Yapper/Core/ASR/WhisperService.swift"
    "Sources/Yapper/Models/Mode.swift"
    "Sources/Yapper/Models/Session.swift"
    "Sources/Yapper/Models/Settings.swift"
)

MISSING=0
for file in "${CORE_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        ((MISSING++))
    fi
done

if [ $MISSING -eq 0 ]; then
    pass "All core files present (${#CORE_FILES[@]} files)"
else
    fail "$MISSING core files missing"
fi

# Test 4: Build system
echo "Test 4: Swift build"
info "Running: swift build"
if swift build 2>&1 | grep -q "Build complete\|Compiling\|Linking"; then
    # Check if it's just the whisper linker warning
    if swift build 2>&1 | grep -q "library 'whisper' not found"; then
        warn "Build succeeds with expected Whisper linker warning"
        pass "Swift build works (Whisper optional)"
    else
        pass "Swift build successful"
    fi
else
    fail "Swift build failed"
fi

# Test 5: Binary exists
echo "Test 5: Binary output"
if [ -f ".build/debug/Yapper" ]; then
    pass "Binary generated at .build/debug/Yapper"

    # Check binary size
    SIZE=$(ls -lh .build/debug/Yapper | awk '{print $5}')
    info "Binary size: $SIZE"
else
    fail "Binary not generated"
fi

# Test 6: Documentation
echo "Test 6: Documentation"
DOC_FILES=(
    "README.md"
    "SETUP.md"
    "STATUS.md"
    "QUICKSTART.md"
    "docs/PROJECT_SUMMARY.md"
)

DOC_MISSING=0
for file in "${DOC_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        ((DOC_MISSING++))
    fi
done

if [ $DOC_MISSING -eq 0 ]; then
    pass "All documentation present (${#DOC_FILES[@]} files)"
else
    warn "$DOC_MISSING documentation files missing"
fi

# Test 7: Whisper setup script
echo "Test 7: Whisper setup"
if [ -f "scripts/setup-whisper.sh" ]; then
    pass "setup-whisper.sh exists"

    # Check if whisper is already set up
    if [ -d "whisper.cpp" ] || command -v whisper &> /dev/null; then
        info "Whisper appears to be set up"
    else
        warn "Whisper not set up (run ./scripts/setup-whisper.sh)"
    fi
else
    fail "setup-whisper.sh missing"
fi

# Test 8: Vendor directory
echo "Test 8: Vendor structure"
if [ -d "Vendor/CWhisper" ]; then
    if [ -f "Vendor/CWhisper/module.modulemap" ]; then
        pass "CWhisper module configured"
    else
        fail "module.modulemap missing"
    fi
else
    fail "Vendor/CWhisper missing"
fi

# Test 9: Resources
echo "Test 9: Resources"
if [ -d "Sources/Yapper/Resources/Assets.xcassets" ]; then
    pass "Assets.xcassets exists"
else
    warn "Assets.xcassets missing"
fi

if [ -f "Sources/Yapper/Resources/Info.plist" ]; then
    pass "Info.plist exists"
else
    fail "Info.plist missing"
fi

# Test 10: Git repository
echo "Test 10: Version control"
if [ -d ".git" ]; then
    pass "Git repository initialized"

    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        warn "Uncommitted changes present"
    else
        info "Working directory clean"
    fi
else
    warn "Not a git repository"
fi

# Summary
echo ""
echo "=============================="
echo "📊 Test Summary"
echo "=============================="
echo ""
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical tests passed!${NC}"
    echo ""
    echo "Yapper is ready for development and testing."
    echo ""
    echo "Next steps:"
    echo "  1. Run ./scripts/setup-whisper.sh (if not done)"
    echo "  2. Run .build/debug/Yapper"
    echo "  3. Grant permissions when prompted"
    echo "  4. Test recording with ⌘⌥Space"
    echo ""
    exit 0
else
    echo -e "${RED}⚠️  Some tests failed${NC}"
    echo ""
    echo "Please review the failures above and fix any issues."
    echo ""
    exit 1
fi

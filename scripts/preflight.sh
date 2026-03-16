#!/bin/bash
# Yapper Pre-Flight Checklist
# Verifies system is ready to run Yapper

echo "✈️  Yapper Pre-Flight Checklist"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0
WARNINGS=0

check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((CHECKS_PASSED++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((CHECKS_FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo "🔍 System Requirements"
echo "---------------------"

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)

echo "macOS Version: $MACOS_VERSION"
if [ "$MACOS_MAJOR" -ge 13 ]; then
    check_pass "macOS 13.0+ ✓"
else
    check_fail "macOS 13.0+ required (found $MACOS_VERSION)"
fi

# Check Xcode/Swift
echo ""
echo "🛠️  Development Tools"
echo "--------------------"

if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -1)
    echo "Swift: $SWIFT_VERSION"
    check_pass "Swift installed"
else
    check_fail "Swift not found (install Xcode Command Line Tools)"
fi

if command -v xcodebuild &> /dev/null; then
    XCODE_VERSION=$(xcodebuild -version | head -1)
    echo "Xcode: $XCODE_VERSION"
    check_pass "Xcode installed"
else
    check_warn "Xcode not found (optional, but recommended)"
fi

# Check build status
echo ""
echo "🏗️  Build Status"
echo "---------------"

cd "$(dirname "$0")/.."

if [ -f ".build/debug/Yapper" ]; then
    check_pass "Binary exists"

    # Check if it's recent
    AGE=$(($(date +%s) - $(stat -f %m .build/debug/Yapper)))
    if [ $AGE -lt 3600 ]; then
        info "Binary is recent (${AGE}s old)"
    else
        check_warn "Binary is old (built $(($AGE/60)) minutes ago) - consider rebuilding"
    fi
else
    check_fail "Binary not found - run 'swift build' first"
fi

# Check Whisper setup
echo ""
echo "🎤 Whisper ASR"
echo "-------------"

if [ -d "whisper.cpp" ]; then
    check_pass "whisper.cpp directory exists"

    if [ -f "whisper.cpp/libwhisper.a" ]; then
        check_pass "libwhisper.a built"
    else
        check_warn "libwhisper.a not found - transcription will use mock mode"
    fi

    # Check for models
    MODEL_COUNT=$(find ~/Documents/Yapper/Models -name "*.bin" 2>/dev/null | wc -l)
    if [ "$MODEL_COUNT" -gt 0 ]; then
        check_pass "$MODEL_COUNT Whisper model(s) downloaded"
    else
        check_warn "No Whisper models downloaded - run './scripts/setup-whisper.sh'"
    fi
else
    check_warn "whisper.cpp not set up - run './scripts/setup-whisper.sh' for real transcription"
    info "App will work with mock transcription for UI development"
fi

# Check permissions
echo ""
echo "🔐 Permissions"
echo "-------------"

# Check if Yapper is running
if pgrep -x "Yapper" > /dev/null; then
    info "Yapper is currently running"

    # Try to get permission status (requires running app)
    info "Permission status will be shown on first run"
else
    info "Yapper not running - permissions will be requested on first launch"
fi

info "Required permissions:"
echo "   • Microphone (for recording)"
echo "   • Accessibility (for text insertion)"
echo "   • Notifications (for user feedback)"

# Check API keys
echo ""
echo "🔑 API Keys"
echo "----------"

HAS_OPENAI=false
HAS_ANTHROPIC=false

if security find-generic-password -s "Yapper.APIKey.OpenAI" &>/dev/null; then
    check_pass "OpenAI API key configured"
    HAS_OPENAI=true
else
    check_warn "OpenAI API key not set (optional for AI modes)"
fi

if security find-generic-password -s "Yapper.APIKey.Anthropic" &>/dev/null; then
    check_pass "Anthropic API key configured"
    HAS_ANTHROPIC=true
else
    check_warn "Anthropic API key not set (optional for AI modes)"
fi

if [ "$HAS_OPENAI" = false ] && [ "$HAS_ANTHROPIC" = false ]; then
    info "AI processing will be disabled without API keys"
    info "Add keys in: Settings > API Keys"
fi

# Check disk space
echo ""
echo "💾 Storage"
echo "---------"

AVAILABLE_GB=$(df -h "$HOME" | tail -1 | awk '{print $4}' | sed 's/Gi//;s/G//')
if [ "${AVAILABLE_GB%%.*}" -ge 2 ]; then
    check_pass "Sufficient disk space ($AVAILABLE_GB available)"
else
    check_warn "Low disk space ($AVAILABLE_GB) - Whisper models need ~2GB"
fi

# Check Yapper data directory
YAPPER_DIR="$HOME/Documents/Yapper"
if [ -d "$YAPPER_DIR" ]; then
    SIZE=$(du -sh "$YAPPER_DIR" 2>/dev/null | cut -f1)
    info "Yapper data: $SIZE at $YAPPER_DIR"
else
    info "Yapper data directory will be created on first run"
fi

# Check for running instances
echo ""
echo "🔄 Running Processes"
echo "-------------------"

YAPPER_PIDS=$(pgrep -x "Yapper" || true)
if [ -n "$YAPPER_PIDS" ]; then
    COUNT=$(echo "$YAPPER_PIDS" | wc -l | tr -d ' ')
    if [ "$COUNT" -eq 1 ]; then
        check_pass "Yapper is running (PID: $YAPPER_PIDS)"
    else
        check_warn "Multiple Yapper instances running - may cause issues"
    fi
else
    info "Yapper is not running"
fi

# Summary
echo ""
echo "================================"
echo "📋 Checklist Summary"
echo "================================"
echo ""
echo -e "Passed:   ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Failed:   ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical checks passed!${NC}"
    echo ""

    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Some optional features need attention (see warnings above)${NC}"
        echo ""
    fi

    echo "Yapper is ready to launch! 🚀"
    echo ""
    echo "To start Yapper:"
    echo "  .build/debug/Yapper"
    echo ""
    echo "Or use menubar after first launch:"
    echo "  • Press ⌘⌥Space to record"
    echo "  • Click menubar icon for menu"
    echo "  • Settings for configuration"
    echo ""

    if [ $WARNINGS -gt 0 ]; then
        echo "Recommended next steps:"
        if ! [ -d "whisper.cpp" ]; then
            echo "  1. ./scripts/setup-whisper.sh (for real transcription)"
        fi
        if [ "$HAS_OPENAI" = false ] && [ "$HAS_ANTHROPIC" = false ]; then
            echo "  2. Add API key in Settings > API Keys (for AI modes)"
        fi
        echo ""
    fi

    exit 0
else
    echo -e "${RED}❌ Critical issues found${NC}"
    echo ""
    echo "Please address the failures above before running Yapper."
    echo ""

    if ! [ -f ".build/debug/Yapper" ]; then
        echo "Quick fix: Run 'swift build' to build the project"
    fi

    echo ""
    exit 1
fi

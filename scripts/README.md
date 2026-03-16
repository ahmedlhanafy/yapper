# Yapper Scripts

Helpful scripts for development, testing, and deployment.

---

## Available Scripts

### 🚀 `setup-whisper.sh`

**Purpose**: One-command setup for Whisper.cpp integration

**What it does**:
- Clones whisper.cpp repository
- Builds libwhisper.a library
- Downloads base model (~150MB)
- Configures pkg-config
- Sets up environment variables

**Usage**:
```bash
./scripts/setup-whisper.sh
```

**Requirements**:
- Git
- Make
- C compiler (clang/gcc)
- ~2GB free disk space

**First-time setup**: Run this before using real transcription.

---

### ✅ `quick-test.sh`

**Purpose**: Fast sanity checks for development

**What it checks**:
- Project structure
- Core files present
- Build system works
- Binary generated
- Documentation exists
- Whisper setup status
- Vendor structure
- Resources present
- Git repository

**Usage**:
```bash
./scripts/quick-test.sh
```

**Exit codes**:
- `0`: All tests passed
- `1`: Some tests failed

**When to use**: After making changes, before committing.

---

### ✈️ `preflight.sh`

**Purpose**: Pre-flight checklist before running Yapper

**What it checks**:
- macOS version (13.0+ required)
- Swift/Xcode installed
- Binary exists and is recent
- Whisper.cpp set up
- Models downloaded
- API keys configured
- Disk space available
- Running processes
- Permission status

**Usage**:
```bash
./scripts/preflight.sh
```

**Output**: Color-coded status report with recommendations

**When to use**: Before testing, before demo, before release.

---

### 🔄 `dev-reset.sh`

**Purpose**: Reset Yapper to clean state

**What it removes**:
- Settings and configuration
- All recorded sessions
- Audio files
- History database
- API keys (optional)
- Build artifacts (optional)

**Usage**:
```bash
./scripts/dev-reset.sh
```

**⚠️ WARNING**: This is destructive! Confirms before deleting.

**When to use**: Testing fresh install, debugging permission issues, starting clean.

---

### 📦 `create-app-bundle.sh`

**Purpose**: Create macOS .app bundle

**What it does**:
- Builds release binary
- Creates Yapper.app structure
- Copies Info.plist
- Sets up resources
- Makes executable

**Usage**:
```bash
./scripts/create-app-bundle.sh
```

**Output**: `Yapper.app` in project root

**When to use**: Testing app bundle, preparing for distribution.

---

## Common Workflows

### First Time Setup

```bash
# 1. Build the project
swift build

# 2. Set up Whisper (optional, for real transcription)
./scripts/setup-whisper.sh

# 3. Run pre-flight checks
./scripts/preflight.sh

# 4. Run Yapper
.build/debug/Yapper
```

### Daily Development

```bash
# After making changes
swift build

# Quick sanity check
./scripts/quick-test.sh

# Run if tests pass
.build/debug/Yapper
```

### Testing Fresh Install

```bash
# Reset to clean state
./scripts/dev-reset.sh

# Rebuild
swift build

# Test first-run experience
.build/debug/Yapper
```

### Preparing Release

```bash
# Pre-flight checks
./scripts/preflight.sh

# Create app bundle
./scripts/create-app-bundle.sh

# Test bundle
open Yapper.app
```

---

## Troubleshooting

### "Permission denied"

Scripts need execute permissions:
```bash
chmod +x scripts/*.sh
```

### "Binary not found"

Build first:
```bash
swift build
```

### "Whisper library not found"

Run setup script:
```bash
./scripts/setup-whisper.sh
```

### "Command not found"

Ensure you're in project root:
```bash
cd /path/to/yapper
./scripts/script-name.sh
```

---

## Script Development

### Adding New Scripts

1. Create `.sh` file in `scripts/` directory
2. Add shebang: `#!/bin/bash`
3. Make executable: `chmod +x scripts/your-script.sh`
4. Document in this README
5. Follow existing script patterns:
   - Color-coded output
   - Clear error messages
   - Confirmation for destructive actions
   - Proper exit codes

### Color Codes

Scripts use ANSI color codes:
```bash
RED='\033[0;31m'      # ❌ Errors
GREEN='\033[0;32m'    # ✅ Success
YELLOW='\033[1;33m'   # ⚠️  Warnings
BLUE='\033[0;34m'     # ℹ️  Info
NC='\033[0m'          # Reset
```

### Best Practices

- Use `set -e` to exit on error
- Confirm before destructive operations
- Provide clear progress messages
- Use functions for repeated logic
- Add help text with `-h` or `--help`
- Return proper exit codes (0 = success, 1 = failure)

---

## Environment Variables

Scripts may use these variables:

- `YAPPER_DIR`: Yapper data directory (default: `~/Documents/Yapper`)
- `WHISPER_DIR`: Whisper.cpp directory (default: `./whisper.cpp`)
- `BUILD_TYPE`: Build configuration (default: `debug`)

Set before running:
```bash
export YAPPER_DIR=/custom/path
./scripts/preflight.sh
```

---

## CI/CD Integration

These scripts are designed to work in CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run tests
  run: ./scripts/quick-test.sh

- name: Pre-flight checks
  run: ./scripts/preflight.sh

- name: Build app bundle
  run: ./scripts/create-app-bundle.sh
```

---

## Contributing

When adding new scripts:

1. Keep them simple and focused
2. Add comprehensive error handling
3. Document usage in this README
4. Test on clean macOS installation
5. Follow existing naming conventions

---

## Support

For issues with scripts:

1. Check script output for error messages
2. Ensure you have required permissions
3. Verify you're in project root directory
4. Check system requirements
5. Report bugs with full error output

---

**Scripts Version**: 1.0
**Last Updated**: January 2026
**Maintained By**: Yapper Development Team

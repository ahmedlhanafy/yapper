# Yapper Quick Test Checklist

**App Status**: ✅ Running (Release Build)
**Version**: 0.1.1 (Post-Whisper Integration)
**Date**: January 8, 2026

---

## 🎯 Critical Path Testing (5 minutes)

### 1. First Launch ✓
- [ ] Menubar icon visible (waveform symbol in top-right)
- [ ] Click icon shows menu
- [ ] No crash on launch

### 2. Permissions (Will be requested)
- [ ] Microphone permission requested
- [ ] Grant microphone access
- [ ] Accessibility permission requested (for text insertion)
- [ ] Grant accessibility access
- [ ] Notification permission requested
- [ ] Grant notification access

### 3. Basic Recording Test
**Steps**:
1. Press **⌘⌥Space** (Command-Option-Space) to start recording
2. Speak clearly: "This is a test of Yapper transcription"
3. Press **⌘⌥Space** again to stop

**Expected**:
- [ ] Recording window appears
- [ ] Waveform animates while speaking
- [ ] Window shows "Recording..." status
- [ ] After stopping, shows "Transcribing..."
- [ ] Text appears (real Whisper transcription!)

**Result**: _________________________________

### 4. Settings Access
- [ ] Click menubar icon → "Settings..."
- [ ] Settings window opens
- [ ] All 6 tabs visible: General, Shortcuts, Modes, Audio, API Keys, Advanced
- [ ] No visual glitches

### 5. History Verification
- [ ] Click menubar icon → "History"
- [ ] Your test recording appears in list
- [ ] Can see transcription text
- [ ] Timestamp is correct

---

## 🔍 Feature Verification (15 minutes)

### Audio System
- [ ] Settings > Audio shows your microphone
- [ ] Audio level meter responds to voice
- [ ] Can select different microphone if available

### Mode System
- [ ] Menubar shows current mode (default: Voice-to-Text)
- [ ] Click mode name to see all 6 built-in modes:
  - [ ] Voice-to-Text
  - [ ] Email
  - [ ] Message
  - [ ] Note
  - [ ] Meeting
  - [ ] Super
- [ ] Can switch between modes

### Transcription Quality
**Test with different phrases**:
1. Simple: "Hello world" → _______________________
2. Technical: "Configure Swift Package Manager" → _______________________
3. Punctuation: "Hello, how are you? I'm fine!" → _______________________

**Quality rating**: ☐ Excellent ☐ Good ☐ Fair ☐ Poor

### Hotkeys
- [ ] ⌘⌥Space starts/stops recording (default)
- [ ] Can see hotkey in Settings > Shortcuts
- [ ] Hotkey works even when app is in background

---

## 🐛 Bug Check (10 minutes)

### Common Issues
- [ ] **Crash on launch**: No ☐ Yes ☐ (describe: _______)
- [ ] **UI glitches**: No ☐ Yes ☐ (describe: _______)
- [ ] **Transcription errors**: No ☐ Yes ☐ (describe: _______)
- [ ] **Permission issues**: No ☐ Yes ☐ (describe: _______)
- [ ] **Slow performance**: No ☐ Yes ☐ (describe: _______)

### Error Messages
If any errors appear:
- [ ] Error message is clear and helpful
- [ ] Error doesn't crash the app
- [ ] Can recover from error

### Memory/Performance
- [ ] App feels responsive
- [ ] Recording starts quickly (< 1 second)
- [ ] Transcription completes in reasonable time
- [ ] No significant battery drain

---

## ✨ Polish Check (5 minutes)

### UI/UX
- [ ] Icons look professional
- [ ] Text is readable
- [ ] Colors are appropriate
- [ ] Windows are properly sized
- [ ] Animations are smooth

### User Experience
- [ ] First-time experience is clear
- [ ] Features are discoverable
- [ ] Error messages are helpful
- [ ] Settings are understandable

---

## 📝 Overall Assessment

### What Works Well
1. _________________________________
2. _________________________________
3. _________________________________

### Issues Found
1. _________________________________
2. _________________________________
3. _________________________________

### Suggested Improvements
1. _________________________________
2. _________________________________
3. _________________________________

---

## 🎯 Ready for Beta?

**Critical Issues**: ☐ None ☐ Minor ☐ Major
**Overall Quality**: ☐ Excellent ☐ Good ☐ Fair ☐ Poor
**Recommendation**: ☐ Ship ☐ Fix issues first ☐ Needs work

**Notes**:
_________________________________
_________________________________
_________________________________

---

## 🚀 Next Steps

### If Testing Passes
1. Run comprehensive TESTING_GUIDE.md (60+ tests)
2. Prepare beta testing program
3. Follow RELEASE_CHECKLIST.md

### If Issues Found
1. Document all bugs clearly
2. Prioritize by severity
3. Fix critical issues first
4. Retest after fixes

---

## 📊 Technical Info

**Build**: Release (.build/release/Yapper)
**Whisper Model**: base.en (141 MB, English-optimized)
**Model Location**: ~/Documents/Yapper/Models/ggml-base.en.bin
**Frameworks**:
- Whisper.cpp (latest, Metal-accelerated)
- ggml 0.9.5
- AVFoundation, AppKit, Accessibility APIs

**Logs Location**: Check console or run `.build/release/Yapper` from terminal

---

**Tester**: _________________
**Date**: _________________
**Duration**: _______ minutes
**Status**: ☐ PASS ☐ FAIL ☐ NEEDS FIXES

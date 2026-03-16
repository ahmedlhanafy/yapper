# Yapper Testing Guide

**Version**: 0.1.0
**Last Updated**: January 2026
**Purpose**: Comprehensive testing procedures for Yapper

---

## Overview

This guide provides step-by-step testing procedures to validate Yapper functionality before release. Follow these tests in order to ensure all features work correctly.

---

## Prerequisites

### System Requirements
- macOS 13.0 or later
- Working microphone
- Internet connection (for AI features)
- ~2GB free disk space (for Whisper models)

### Setup Steps
1. Build Yapper: `swift build`
2. Run setup script: `./scripts/setup-whisper.sh`
3. Grant permissions when prompted
4. Download Base model via Settings

---

## Test Suite 1: Basic Functionality

### Test 1.1: Application Launch
**Objective**: Verify app starts correctly

**Steps**:
1. Run `.build/debug/Yapper`
2. Check menubar shows waveform icon
3. Click menubar icon
4. Verify menu appears with options

**Expected Results**:
- ✅ App launches without errors
- ✅ Menubar icon visible
- ✅ Menu displays correctly
- ✅ No crash or hang

**Pass/Fail**: ___________

---

### Test 1.2: Settings Access
**Objective**: Verify settings window opens

**Steps**:
1. Click menubar icon
2. Select "Settings..."
3. Navigate through all tabs

**Expected Results**:
- ✅ Settings window opens
- ✅ All 6 tabs accessible (General, Shortcuts, Modes, Audio, API Keys, Advanced)
- ✅ No visual glitches
- ✅ Window resizable

**Pass/Fail**: ___________

---

## Test Suite 2: Audio System

### Test 2.1: Microphone Permission
**Objective**: Verify permission request flow

**Steps**:
1. Fresh install (reset permissions in System Settings if needed)
2. Attempt to start recording
3. System should prompt for microphone access
4. Grant permission
5. Retry recording

**Expected Results**:
- ✅ Permission dialog appears
- ✅ App detects permission grant
- ✅ Recording works after granting
- ✅ Clear error message if denied

**Pass/Fail**: ___________

---

### Test 2.2: Audio Capture
**Objective**: Verify audio recording works

**Steps**:
1. Open Settings > Audio
2. Verify microphone shows in device list
3. Speak into microphone
4. Check audio levels respond
5. Start recording via hotkey (⌘⌥Space)
6. Speak for 5 seconds
7. Stop recording

**Expected Results**:
- ✅ Audio device detected
- ✅ Level meter responds to voice
- ✅ Recording starts/stops on command
- ✅ No audio glitches or dropouts
- ✅ Waveform visualization works

**Pass/Fail**: ___________

---

### Test 2.3: Audio Normalization
**Objective**: Verify audio preprocessing

**Steps**:
1. Enable "Audio normalization" in Settings
2. Record with quiet voice
3. Record with loud voice
4. Compare transcription quality

**Expected Results**:
- ✅ Quiet audio still transcribes
- ✅ Loud audio doesn't distort
- ✅ Consistent quality
- ✅ No artifacts

**Pass/Fail**: ___________

---

## Test Suite 3: Transcription

### Test 3.1: Whisper Model Download
**Objective**: Verify model management UI

**Steps**:
1. Open Settings > Advanced > Whisper Models
2. Click "Download" on Base model
3. Monitor progress
4. Wait for completion

**Expected Results**:
- ✅ Download starts
- ✅ Progress bar updates
- ✅ Download completes
- ✅ Checkmark shows when done
- ✅ "Re-download" and "Delete" options appear

**Pass/Fail**: ___________

---

### Test 3.2: Basic Transcription
**Objective**: Verify speech-to-text works

**Test Cases**:
1. **Short phrase**: "Hello world"
2. **Sentence**: "The quick brown fox jumps over the lazy dog"
3. **Paragraph**: Speak continuously for 30 seconds

**Steps** (for each test case):
1. Press ⌘⌥Space
2. Speak clearly
3. Press ⌘⌥Space again
4. Wait for transcription
5. Check result in History

**Expected Results**:
- ✅ Transcription accurate (>90%)
- ✅ Punctuation reasonable
- ✅ Processing time <5 seconds
- ✅ Text appears in History

**Pass/Fail**: ___________

---

### Test 3.3: Multi-Language
**Objective**: Verify language support

**Test Languages**:
- English
- Spanish ("Hola, ¿cómo estás?")
- French ("Bonjour, comment ça va?")

**Steps** (for each language):
1. Create custom mode with target language
2. Record in that language
3. Check transcription

**Expected Results**:
- ✅ Correct language detected
- ✅ Accurate transcription
- ✅ Proper character encoding

**Pass/Fail**: ___________

---

## Test Suite 4: AI Processing

### Test 4.1: API Key Configuration
**Objective**: Verify API key storage

**Steps**:
1. Open Settings > API Keys
2. Enter OpenAI API key
3. Click "Save"
4. Close settings
5. Reopen settings
6. Verify key is saved (shows as asterisks)

**Expected Results**:
- ✅ Key saves successfully
- ✅ Key persists after app restart
- ✅ Key stored in Keychain (not plain text)
- ✅ Clear button works

**Pass/Fail**: ___________

---

### Test 4.2: Email Mode Processing
**Objective**: Verify AI enhancement works

**Steps**:
1. Select "Email" mode from menubar
2. Record: "Hey Bob I wanted to ask about that thing we discussed yesterday can you send me the files"
3. Wait for processing
4. Check result

**Expected Results**:
- ✅ Text is professionally formatted
- ✅ Proper greeting added
- ✅ Improved grammar and structure
- ✅ Appropriate closing
- ✅ Processing time <10 seconds

**Pass/Fail**: ___________

---

### Test 4.3: Translation
**Objective**: Verify translation feature

**Steps**:
1. Create mode with "Translate to English" enabled
2. Speak in Spanish: "Quiero comprar una casa"
3. Check result

**Expected Results**:
- ✅ Output is in English
- ✅ Translation accurate
- ✅ Natural English phrasing

**Pass/Fail**: ___________

---

## Test Suite 5: Context Capture

### Test 5.1: Clipboard Context
**Objective**: Verify clipboard capture

**Steps**:
1. Copy text: "Project deadline: January 15"
2. Wait 1 second (within 3-second window)
3. Start recording
4. Say: "Schedule a meeting to discuss"
5. Stop recording
6. Check AI includes copied text in context

**Expected Results**:
- ✅ Clipboard content captured
- ✅ AI references copied text
- ✅ Context is relevant
- ✅ Works within 3-second window

**Pass/Fail**: ___________

---

### Test 5.2: Selected Text Context
**Objective**: Verify text selection capture

**Steps**:
1. Open TextEdit
2. Type: "We need to improve user onboarding"
3. Select the text
4. Start recording (with selection enabled in mode)
5. Say: "Add this to the roadmap"
6. Check result includes context

**Expected Results**:
- ✅ Selected text captured
- ✅ AI references selection
- ✅ Context is appropriate
- ✅ Requires Accessibility permission

**Pass/Fail**: ___________

---

### Test 5.3: Browser URL Context
**Objective**: Verify browser context capture

**Steps**:
1. Open Safari
2. Navigate to https://github.com/yapper
3. Start recording
4. Say: "Summarize this page"
5. Check AI includes URL in context

**Expected Results**:
- ✅ URL captured
- ✅ AI knows context
- ✅ Works with Safari, Chrome
- ✅ Page title included

**Pass/Fail**: ___________

---

## Test Suite 6: Text Insertion

### Test 6.1: Basic Insertion
**Objective**: Verify text insertion works

**Test Apps**:
- TextEdit (native macOS)
- Notes.app
- Mail.app
- Messages.app
- Browser (Chrome, Safari)

**Steps** (for each app):
1. Open app and create new document/message
2. Click in text field
3. Press ⌘⌥Space
4. Say: "This is a test"
5. Stop recording
6. Verify text appears

**Expected Results**:
- ✅ Text inserts at cursor
- ✅ Works in all test apps
- ✅ No clipboard pollution
- ✅ Proper spacing

**Pass/Fail**: ___________

---

### Test 6.2: Output Modes
**Objective**: Verify output behavior options

**Test Cases**:
1. **Insert at cursor**: Text should paste
2. **Copy to clipboard**: Text in clipboard, not pasted
3. **Both**: Text pasted AND copied

**Steps** (for each mode):
1. Configure mode with output behavior
2. Record text
3. Check result

**Expected Results**:
- ✅ Insert mode: Text appears at cursor
- ✅ Copy mode: Clipboard contains text
- ✅ Both mode: Text AND clipboard
- ✅ Mode switching works

**Pass/Fail**: ___________

---

### Test 6.3: Secure Field Detection
**Objective**: Verify password field handling

**Steps**:
1. Open System Settings
2. Navigate to Users & Groups
3. Try to insert text in password field
4. Record dictation

**Expected Results**:
- ✅ Detects secure field
- ✅ Falls back to clipboard
- ✅ Error message clear
- ✅ No crash

**Pass/Fail**: ___________

---

## Test Suite 7: Mode System

### Test 7.1: Mode Switching
**Objective**: Verify mode changes work

**Steps**:
1. Click menubar icon
2. Hover over "Select Mode"
3. Click each mode
4. Verify checkmark moves
5. Try cycle hotkey (⌘⇧,)

**Expected Results**:
- ✅ Mode changes immediately
- ✅ Visual feedback (checkmark)
- ✅ Hotkey cycles through modes
- ✅ Current mode persists

**Pass/Fail**: ___________

---

### Test 7.2: Custom Mode Creation
**Objective**: Verify mode editor

**Steps**:
1. Open Settings > Modes
2. Click "New Mode"
3. Fill in:
   - Name: "Test Mode"
   - Language: English
   - Enable AI: Yes
   - Provider: OpenAI
   - Instructions: "Be concise"
4. Click "Create"
5. Verify mode appears in list

**Expected Results**:
- ✅ Mode editor opens
- ✅ All fields editable
- ✅ Validation works
- ✅ Mode saves successfully
- ✅ Mode usable immediately

**Pass/Fail**: ___________

---

### Test 7.3: Mode Editing
**Objective**: Verify mode updates work

**Steps**:
1. Select existing custom mode
2. Click "Edit"
3. Change AI instructions
4. Click "Save"
5. Record with mode
6. Verify changes applied

**Expected Results**:
- ✅ Editor shows current values
- ✅ Changes save
- ✅ Mode updates immediately
- ✅ Built-in modes read-only

**Pass/Fail**: ___________

---

## Test Suite 8: Hotkeys

### Test 8.1: Hotkey Recording
**Objective**: Verify hotkey recorder

**Steps**:
1. Open Settings > Shortcuts
2. Click "Record" for recording hotkey
3. Press ⌘⌥R
4. Click "Stop"
5. Verify displayed: "⌘⌥R"

**Expected Results**:
- ✅ Recording starts
- ✅ Keys display in real-time
- ✅ Modifiers required
- ✅ Invalid combos rejected
- ✅ Saves on stop

**Pass/Fail**: ___________

---

### Test 8.2: Hotkey Functionality
**Objective**: Verify hotkeys work globally

**Steps**:
1. Set recording hotkey to ⌘⌥R
2. Switch to different app (e.g., Browser)
3. Press ⌘⌥R
4. Verify recording starts
5. Press again to stop

**Expected Results**:
- ✅ Works from any app
- ✅ Yapper not focused
- ✅ Visual feedback (mini window)
- ✅ Menubar icon changes

**Pass/Fail**: ___________

---

### Test 8.3: Hotkey Conflicts
**Objective**: Verify conflict handling

**Steps**:
1. Try to set common system hotkey (⌘Space)
2. Check for warning/error
3. Set unique hotkey
4. Verify works

**Expected Results**:
- ✅ System hotkeys don't register
- ✅ Clear error message
- ✅ Alternative suggested
- ✅ No system disruption

**Pass/Fail**: ___________

---

## Test Suite 9: History

### Test 9.1: Session Tracking
**Objective**: Verify sessions save correctly

**Steps**:
1. Record 3 different dictations
2. Open History view
3. Verify all 3 appear
4. Check metadata (timestamp, mode, duration)

**Expected Results**:
- ✅ All sessions listed
- ✅ Correct timestamps
- ✅ Mode names accurate
- ✅ Duration calculated

**Pass/Fail**: ___________

---

### Test 9.2: Audio Playback
**Objective**: Verify recorded audio plays

**Steps**:
1. Select session from history
2. Click play button
3. Listen to audio
4. Try pause, seek

**Expected Results**:
- ✅ Audio plays correctly
- ✅ Pause/resume works
- ✅ Seek bar functional
- ✅ Audio quality good

**Pass/Fail**: ___________

---

### Test 9.3: Session Reprocessing
**Objective**: Verify reprocessing feature

**Steps**:
1. Record in "Voice-to-Text" mode
2. Open History, select session
3. Click "Reprocess"
4. Select "Email" mode
5. Verify different output

**Expected Results**:
- ✅ Reprocessing works
- ✅ Different mode produces different output
- ✅ Original audio preserved
- ✅ Both versions accessible

**Pass/Fail**: ___________

---

## Test Suite 10: Error Handling

### Test 10.1: No Microphone Permission
**Objective**: Verify permission error handling

**Steps**:
1. Deny microphone permission in System Settings
2. Try to record
3. Check error message

**Expected Results**:
- ✅ Clear error message
- ✅ Instructions to fix
- ✅ Link to System Settings
- ✅ No crash

**Pass/Fail**: ___________

---

### Test 10.2: No API Key
**Objective**: Verify AI error handling

**Steps**:
1. Remove API keys
2. Try AI mode
3. Check error

**Expected Results**:
- ✅ Clear error: "API key missing"
- ✅ Link to Settings
- ✅ Transcription still works
- ✅ No crash

**Pass/Fail**: ___________

---

### Test 10.3: Network Error
**Objective**: Verify offline handling

**Steps**:
1. Disable WiFi
2. Try AI processing
3. Check error
4. Re-enable WiFi
5. Retry

**Expected Results**:
- ✅ Clear offline error
- ✅ Local transcription still works
- ✅ Retry suggested
- ✅ Recovers when online

**Pass/Fail**: ___________

---

### Test 10.4: Model Not Downloaded
**Objective**: Verify model error handling

**Steps**:
1. Delete all models
2. Try to transcribe
3. Check error message

**Expected Results**:
- ✅ Clear error: "Model not downloaded"
- ✅ Link to model manager
- ✅ Suggested model shown
- ✅ No crash

**Pass/Fail**: ___________

---

## Test Suite 11: Performance

### Test 11.1: Cold Start
**Objective**: Measure startup time

**Steps**:
1. Quit Yapper completely
2. Start timer
3. Launch Yapper
4. Wait for menubar icon
5. Stop timer

**Expected Results**:
- ✅ Launches in <3 seconds
- ✅ Menubar responsive immediately
- ✅ No hangs or freezes

**Pass/Fail**: ___________ (Time: _____s)

---

### Test 11.2: First Transcription
**Objective**: Measure initial load time

**Steps**:
1. Fresh launch
2. Start recording immediately
3. Speak for 5 seconds
4. Stop and wait
5. Measure time to result

**Expected Results**:
- ✅ First transcription <30 seconds
- ✅ Model loads in background
- ✅ Progress indicator shown

**Pass/Fail**: ___________ (Time: _____s)

---

### Test 11.3: Subsequent Transcriptions
**Objective**: Measure warm performance

**Steps**:
1. After first transcription
2. Record 5 more times
3. Measure each

**Expected Results**:
- ✅ Each transcription <5 seconds
- ✅ Consistent performance
- ✅ No memory leaks

**Pass/Fail**: ___________ (Avg: _____s)

---

### Test 11.4: Memory Usage
**Objective**: Verify memory efficiency

**Steps**:
1. Launch Activity Monitor
2. Find Yapper process
3. Record initial memory
4. Perform 10 transcriptions
5. Check final memory

**Expected Results**:
- ✅ Initial: <200MB
- ✅ After 10: <500MB
- ✅ No significant leaks
- ✅ Keep-warm models stay loaded

**Pass/Fail**: ___________ (Initial: _____MB, Final: _____MB)

---

## Test Suite 12: Edge Cases

### Test 12.1: Very Short Audio
**Objective**: Handle brief recordings

**Steps**:
1. Record for <0.5 seconds
2. Check result

**Expected Results**:
- ✅ Error: "Recording too short"
- ✅ Minimum 1 second suggested
- ✅ No crash

**Pass/Fail**: ___________

---

### Test 12.2: Very Long Audio
**Objective**: Handle extended recordings

**Steps**:
1. Record for 5 minutes continuously
2. Check transcription

**Expected Results**:
- ✅ Handles long audio
- ✅ Transcription complete
- ✅ No timeout
- ✅ File size reasonable

**Pass/Fail**: ___________

---

### Test 12.3: Background Noise
**Objective**: Test noise handling

**Steps**:
1. Play background music
2. Speak over it
3. Check transcription quality

**Expected Results**:
- ✅ Still transcribes
- ✅ Some accuracy loss acceptable
- ✅ No artifacts
- ✅ Normalization helps

**Pass/Fail**: ___________

---

### Test 12.4: Rapid Mode Switching
**Objective**: Test state management

**Steps**:
1. Quickly switch modes 10 times
2. Record in each
3. Check results

**Expected Results**:
- ✅ No crashes
- ✅ Correct mode applied
- ✅ UI stays responsive
- ✅ No race conditions

**Pass/Fail**: ___________

---

## Test Suite 13: Persistence

### Test 13.1: Settings Persistence
**Objective**: Verify settings save

**Steps**:
1. Change all settings
2. Quit Yapper
3. Relaunch
4. Check all settings

**Expected Results**:
- ✅ All settings preserved
- ✅ Hotkeys remembered
- ✅ Modes intact
- ✅ API keys saved

**Pass/Fail**: ___________

---

### Test 13.2: History Persistence
**Objective**: Verify history saves

**Steps**:
1. Record 5 sessions
2. Quit Yapper
3. Relaunch
4. Check history

**Expected Results**:
- ✅ All sessions present
- ✅ Audio files intact
- ✅ Metadata correct
- ✅ Playback works

**Pass/Fail**: ___________

---

## Test Suite 14: UI/UX

### Test 14.1: Mini Window
**Objective**: Test floating indicator

**Steps**:
1. Enable mini window in Settings
2. Check it appears in top-right
3. Hover over it
4. Click controls
5. Try different states (idle, recording, processing)

**Expected Results**:
- ✅ Window appears correctly
- ✅ Hover expands it
- ✅ Controls functional
- ✅ Status colors correct
- ✅ Always on top

**Pass/Fail**: ___________

---

### Test 14.2: Waveform Visualization
**Objective**: Test recording UI

**Steps**:
1. Start recording via hotkey
2. Speak at different volumes
3. Watch waveform
4. Check responsiveness

**Expected Results**:
- ✅ Bars respond to voice
- ✅ Smooth animation
- ✅ Accurate representation
- ✅ 20 bars visible

**Pass/Fail**: ___________

---

### Test 14.3: Error Messages
**Objective**: Verify user-friendly errors

**Steps**:
1. Trigger various errors (permission, API, network)
2. Read error messages
3. Check clarity

**Expected Results**:
- ✅ Clear, non-technical language
- ✅ Actionable suggestions
- ✅ Proper formatting
- ✅ No stack traces shown

**Pass/Fail**: ___________

---

## Final Checklist

Before declaring Yapper ready for release, ensure all critical tests pass:

### Critical Tests
- [ ] Application launches without errors
- [ ] Audio recording works
- [ ] Transcription produces accurate results
- [ ] AI processing enhances text
- [ ] Text insertion works in major apps
- [ ] Hotkeys function globally
- [ ] Settings persist across restarts
- [ ] History tracks all sessions
- [ ] Error handling is graceful
- [ ] No crashes in normal use

### Performance Benchmarks
- [ ] Cold start: <3 seconds
- [ ] First transcription: <30 seconds
- [ ] Warm transcription: <5 seconds
- [ ] Memory usage: <500MB after 10 uses

### User Experience
- [ ] UI is responsive
- [ ] Error messages are helpful
- [ ] Permissions clearly explained
- [ ] All features discoverable
- [ ] Documentation complete

---

## Bug Reporting Template

When you find a bug, report it using this format:

```
**Bug Title**: Brief description

**Severity**: Critical / High / Medium / Low

**Steps to Reproduce**:
1. Step one
2. Step two
3. ...

**Expected Behavior**:
What should happen

**Actual Behavior**:
What actually happened

**Environment**:
- macOS Version:
- Yapper Version:
- Model Used:
- Mode:

**Screenshots/Logs**:
Attach if available

**Additional Context**:
Any other relevant information
```

---

## Test Results Summary

**Date**: ___________
**Tester**: ___________
**Version**: ___________

**Overall Results**:
- Total Tests: 60
- Passed: _____
- Failed: _____
- Skipped: _____

**Pass Rate**: _____%

**Critical Issues Found**: _____

**Release Recommendation**:
- [ ] Ready for release
- [ ] Needs minor fixes
- [ ] Needs major fixes
- [ ] Not ready

**Notes**:
___________________________________
___________________________________
___________________________________

---

**End of Testing Guide**

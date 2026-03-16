<p align="center">
  <img src="yapper-icon.png" width="128" height="128" alt="Yapper icon">
  <br>
  <h1 align="center">Yapper</h1>
</p>

Dictation app for macOS. Talk, and it types. Runs Whisper locally so nothing leaves your machine unless you want AI cleanup via OpenAI or Anthropic.

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue" alt="macOS 13.0+">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange" alt="Swift 5.9+">
  <img src="https://img.shields.io/badge/Beta-yellow" alt="Beta">
</p>

---

## What it does

You press a hotkey, say something, and the text shows up wherever your cursor is. Six built-in modes handle different situations: plain transcription, email tone, casual messages, structured notes, meeting capture, and a "super" mode that sends everything through cloud AI. You can also build your own modes.

The AI modes pull in context from your clipboard, selected text, and whatever app you're in, so they have some idea what you're working on.

---

## Get running

You need macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

```bash
./scripts/setup-whisper.sh   # builds whisper.cpp, downloads base model (~150MB)
swift build
.build/debug/Yapper
```

macOS will ask for microphone and accessibility permissions. Say yes to both.

Try it: click the menubar icon, press Option+Space, say something, press Option+Space again. Text should appear at your cursor.

For a release build that produces a signed .app bundle:

```bash
./build.sh   # output goes to dist/Yapper.app
```

---

## Modes

| Mode | What it does |
|------|-------------|
| Voice-to-Text | Straight transcription, no processing |
| Email | Cleans up your words into professional tone |
| Message | Keeps it casual |
| Note | Adds structure |
| Meeting | Detailed capture for conference notes |
| Super | Sends transcription through cloud AI for heavier rewriting |

Email, Message, Note, Meeting, and Super need an API key (OpenAI or Anthropic). Add one in Settings > API Keys. Keys go into macOS Keychain.

---

## Project layout

```
Sources/Yapper/
├── YapperApp.swift              # entry point
├── Core/
│   ├── Audio/AudioEngine        # mic recording (AVFoundation)
│   ├── ASR/WhisperService       # local transcription (whisper.cpp)
│   ├── AI/AIProcessor           # cloud AI calls
│   ├── Context/ContextCapture   # reads clipboard, selection, active app
│   ├── Output/TextInserter      # pastes text via Accessibility APIs
│   ├── Storage/StorageManager   # settings + history as JSON, keys in Keychain
│   ├── RecordingCoordinator     # coordinates record -> transcribe -> insert
│   └── HotkeyManager           # global hotkeys (Carbon Events)
├── Models/                      # Mode, Session, Settings structs
├── Views/                       # SwiftUI UI
└── Resources/                   # assets, Info.plist
```

Built with Swift Package Manager. Whisper.cpp is linked as a C library through the `Vendor/CWhisper` system library target.

---

## Working on it

Add a mode: edit `Sources/Yapper/Models/Mode.swift`, define a static `Mode`, add it to `allBuiltIn`.

Change AI prompts: edit the `instructions` field on any mode.

Add an AI provider: add a case to `AIProvider` in `Core/AI/AIProcessor.swift` and write the API call.

Change hotkeys: Settings > Shortcuts in the app, or edit defaults in `Settings.swift`.

Run tests with `swift test`. For manual testing, the short version: does it record, transcribe, and insert text into TextEdit? Do settings survive a restart? See [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md) for the full list.

---

## When things break

| Problem | What to do |
|---------|-----------|
| Mic permission denied | System Settings > Privacy & Security > Microphone, toggle Yapper on |
| Text won't paste | Same path but Accessibility instead of Microphone |
| "Model not found" | Run `./scripts/setup-whisper.sh` or grab one from Settings > Advanced > Models |
| Whisper linker errors at build time | Normal if you haven't run setup-whisper.sh yet. App falls back to mock transcription. |
| API calls failing | Check your key in Settings > API Keys. Make sure you're online. |
| Weird build cache errors | `swift package clean && swift build` |

---

## More docs

- [Whisper integration guide](docs/WHISPER_INTEGRATION_GUIDE.md)
- [Testing guide](docs/TESTING_GUIDE.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Branding](docs/BRANDING.md)
- [Project summary](docs/PROJECT_SUMMARY.md)

---

## Status

The core works: recording, local transcription, AI processing, context capture, text insertion, modes, hotkeys, settings, history. All there.

Next up is proper end-to-end testing and getting it into the App Store. Siri/Shortcuts and export/import are on the list after that.

---

## FAQ

**Do I need internet?** Only for the AI-enhanced modes. Plain transcription runs entirely on your Mac.

**Which Whisper model?** Base is a good default. Tiny if you want speed, Large if you care more about accuracy.

**Works with every app?** Most of them. Password fields and some sandboxed apps block text insertion.

---

## Thanks

- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov
- [OpenAI Whisper](https://openai.com/research/whisper)
- Anthropic Claude

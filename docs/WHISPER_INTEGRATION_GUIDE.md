# Whisper.cpp Integration Guide

This guide explains how to integrate whisper.cpp for local speech recognition in Yapper.

---

## Overview

Yapper uses **whisper.cpp** (https://github.com/ggerganov/whisper.cpp) for local, privacy-focused speech recognition. The current build includes a complete Swift interface (`WhisperService.swift`) but uses mock transcription for UI development.

---

## Integration Approach

### Option 1: System Target (Recommended)

Add whisper.cpp as a system library in Package.swift:

```swift
// Package.swift
let package = Package(
    name: "Yapper",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Yapper", targets: ["Yapper"])
    ],
    targets: [
        .systemLibrary(
            name: "CWhisper",
            path: "Vendor/CWhisper",
            pkgConfig: "whisper"
        ),
        .executableTarget(
            name: "Yapper",
            dependencies: ["CWhisper"],
            path: "Sources/Yapper"
        )
    ]
)
```

Create bridging module:

```bash
mkdir -p Vendor/CWhisper
```

**Vendor/CWhisper/module.modulemap**:
```modulemap
module CWhisper {
    header "whisper.h"
    link "whisper"
    export *
}
```

### Option 2: Pre-built Binary

1. Build whisper.cpp separately:
```bash
cd Vendor
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
make libwhisper.a
```

2. Link in Xcode project (not SPM):
```swift
// Create xcodeproj first
swift package generate-xcodeproj

// Add to Xcode:
// - Link libwhisper.a
// - Add include path
// - Configure bridging header
```

### Option 3: Swift Package (whisper-spm)

Use existing Swift wrapper (if available):
```swift
dependencies: [
    .package(url: "https://github.com/ggerganov/whisper.spm", from: "1.5.0")
]
```

---

## Implementation Plan

### Step 1: Setup C Library

1. Clone whisper.cpp:
```bash
cd Vendor
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
```

2. Build library:
```bash
make clean
make libwhisper.a

# Should produce: libwhisper.a
```

3. Download a model for testing:
```bash
bash ./models/download-ggml-model.sh base
# Downloads ggml-base.bin (~142 MB)
```

### Step 2: Create Swift Bridge

**Sources/Yapper/Core/ASR/WhisperBridge.swift**:
```swift
import Foundation

// C API wrapper
// TODO: Import CWhisper module

class WhisperBridge {
    private var context: OpaquePointer?

    func loadModel(path: String) throws {
        // Load model with whisper_init_from_file
    }

    func transcribe(audioPath: String, language: String = "auto") throws -> String {
        // Call whisper_full() and extract text
    }

    func transcribeBuffer(samples: [Float], sampleRate: Int = 16000) throws -> String {
        // Transcribe from memory buffer
    }

    deinit {
        // whisper_free(context)
    }
}
```

### Step 3: Update WhisperService

Replace mock implementation in `performTranscription`:

```swift
private func performTranscription(audioURL: URL, language: String) async throws -> TranscriptionResult {
    let bridge = WhisperBridge()

    // Load model if needed
    let modelPath = modelURL(for: loadedModel!).path
    try bridge.loadModel(path: modelPath)

    // Transcribe
    let text = try bridge.transcribe(audioPath: audioURL.path, language: language)

    return TranscriptionResult(
        text: text,
        language: language,
        segments: [],
        processingTime: Date().timeIntervalSince(startTime)
    )
}
```

### Step 4: Handle Threading

Whisper is CPU-intensive:

```swift
// Run on background queue
private let processingQueue = DispatchQueue(
    label: "com.yapper.whisper",
    qos: .userInitiated
)

func transcribe(...) async throws -> TranscriptionResult {
    return try await withCheckedThrowingContinuation { continuation in
        processingQueue.async {
            do {
                let result = try self.performTranscriptionSync(...)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

### Step 5: Model Management

Implement actual downloads in `downloadModel`:

```swift
func downloadModel(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
    let downloadURL = modelDownloadURL(for: model)
    let modelPath = modelURL(for: model)

    let session = URLSession.shared
    let (asyncBytes, response) = try await session.bytes(from: downloadURL)

    guard let totalBytes = response.expectedContentLength else {
        throw WhisperError.downloadFailed
    }

    let handle = try FileHandle(forWritingTo: modelPath)
    defer { try? handle.close() }

    var receivedBytes: Int64 = 0
    for try await byte in asyncBytes {
        try handle.write(contentsOf: [byte])
        receivedBytes += 1

        if receivedBytes % 1024000 == 0 { // Every MB
            await MainActor.run {
                progress(Double(receivedBytes) / Double(totalBytes))
            }
        }
    }
}
```

---

## Testing Strategy

### 1. Unit Tests

```swift
func testWhisperBridgeLoadModel() throws {
    let bridge = WhisperBridge()
    let modelPath = "/path/to/ggml-base.bin"

    XCTAssertNoThrow(try bridge.loadModel(path: modelPath))
}

func testTranscribeShortAudio() async throws {
    let service = WhisperService.shared
    let audioURL = URL(fileURLWithPath: "/path/to/test.wav")

    let result = try await service.transcribe(
        audioURL: audioURL,
        model: .base,
        language: "en"
    )

    XCTAssertFalse(result.text.isEmpty)
    XCTAssertEqual(result.language, "en")
}
```

### 2. Performance Tests

```swift
func testTranscriptionLatency() async throws {
    // 10-second audio should transcribe in < 2 seconds on M1
    let start = Date()
    let result = try await service.transcribe(...)
    let latency = Date().timeIntervalSince(start)

    XCTAssertLessThan(latency, 2.0)
}

func testKeepWarmPerformance() async throws {
    // Preload model
    try await service.preloadModel(.base, keepAliveDuration: 60)

    // First transcription should be fast
    let start = Date()
    let result = try await service.transcribe(...)
    let latency = Date().timeIntervalSince(start)

    XCTAssertLessThan(latency, 1.5)
}
```

### 3. Integration Tests

```swift
func testEndToEndWorkflow() async throws {
    // 1. Record audio
    let audioURL = try AudioEngine.shared.startRecording()
    sleep(3)
    AudioEngine.shared.stopRecording()

    // 2. Transcribe
    let result = try await WhisperService.shared.transcribe(
        audioURL: audioURL,
        model: .base,
        language: "auto"
    )

    // 3. Process with AI
    let processed = try await AIProcessor.shared.process(
        transcript: result.text,
        mode: Mode.email
    )

    XCTAssertFalse(processed.output.isEmpty)
}
```

---

## Performance Optimization

### Model Selection

| Model | Size | Speed (M1) | Accuracy | Use Case |
|-------|------|------------|----------|----------|
| tiny | 75 MB | ~0.5s / 10s | Good | Quick notes |
| base | 142 MB | ~1.0s / 10s | Better | Default |
| small | 466 MB | ~3.0s / 10s | Great | Long form |
| medium | 1.5 GB | ~10s / 10s | Excellent | Meetings |
| large | 2.9 GB | ~25s / 10s | Best | Critical |

### Recommendations:
- **Default**: base (good balance)
- **Keep-warm**: Small memory footprint (~150-500 MB)
- **File transcription**: medium or large
- **Real-time**: tiny or base only

### Memory Management

```swift
// Release model after idle time
var idleTimer: Timer?

func onTranscriptionComplete() {
    idleTimer?.invalidate()
    idleTimer = Timer.scheduledTimer(withTimeInterval: 300) { [weak self] _ in
        self?.unloadModel()
    }
}
```

### CPU Optimization

```swift
// Use all cores
whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
params.n_threads = ProcessInfo.processInfo.processorCount
```

---

## Error Handling

### Common Issues

1. **Model not found**:
```swift
guard FileManager.default.fileExists(atPath: modelPath) else {
    throw WhisperError.modelNotFound(model)
}
```

2. **Invalid audio format**:
```swift
// Whisper expects 16kHz mono
guard audioFormat.sampleRate == 16000 && audioFormat.channelCount == 1 else {
    throw WhisperError.invalidAudioFormat
}
```

3. **Out of memory**:
```swift
// Monitor memory usage
let memoryUsage = getMemoryUsage()
if memoryUsage > threshold {
    unloadModel()
}
```

4. **Transcription timeout**:
```swift
// Add timeout to prevent hanging
let result = try await withTimeout(seconds: 30) {
    try await bridge.transcribe(...)
}
```

---

## Troubleshooting

### Build Issues

**Linker error: "Undefined symbols for whisper_*"**
- Ensure libwhisper.a is in library search path
- Check architecture (arm64 for M1/M2, x86_64 for Intel)
- Verify module.modulemap is correct

**"Cannot find 'CWhisper' in scope"**
- Add CWhisper to target dependencies
- Import CWhisper in bridging header
- Clean build folder (`swift package clean`)

### Runtime Issues

**Crash on whisper_init_from_file**
- Check model file is valid ggml format
- Verify file permissions
- Ensure sufficient memory available

**Slow transcription**
- Check CPU usage (should be high during transcription)
- Verify n_threads is set correctly
- Consider smaller model

**Incorrect transcriptions**
- Check audio quality (16kHz mono, clear speech)
- Try different model (larger = more accurate)
- Verify language parameter

---

## Model Downloads

### Official Sources

Hugging Face (recommended):
```
https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-{model}.bin
```

OpenAI CDN:
```
https://openaipublic.azureedge.net/main/whisper/models/{hash}/ggml-{model}.bin
```

### Checksums

Verify model integrity:
```swift
func verifyModel(path: String, expectedSHA256: String) throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let hash = SHA256.hash(data: data)
    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

    guard hashString == expectedSHA256 else {
        throw WhisperError.checksumMismatch
    }
}
```

---

## Alternative: Cloud ASR

If local Whisper is too complex initially, consider cloud alternatives:

### OpenAI Whisper API
```swift
func transcribeViaAPI(audioURL: URL) async throws -> String {
    let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Upload audio file
    let (data, _) = try await URLSession.shared.upload(
        for: request,
        fromFile: audioURL
    )

    let json = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    return json.text
}
```

**Pros**: Simple, fast, accurate
**Cons**: Requires internet, costs money, privacy concerns

---

## Next Steps

1. ✅ Choose integration approach (recommend: System Target)
2. ⏳ Build whisper.cpp library
3. ⏳ Create Swift bridge
4. ⏳ Update WhisperService implementation
5. ⏳ Add threading & error handling
6. ⏳ Implement model downloads
7. ⏳ Test with real audio
8. ⏳ Performance tuning

**Estimated Time**: 1-2 iterations with focused work

---

## Resources

- **whisper.cpp**: https://github.com/ggerganov/whisper.cpp
- **Whisper Paper**: https://arxiv.org/abs/2212.04356
- **OpenAI Whisper**: https://github.com/openai/whisper
- **Models**: https://huggingface.co/ggerganov/whisper.cpp
- **Swift C Interop**: https://www.swift.org/documentation/cxx-interop/

---

## Success Criteria

When Whisper integration is complete, you should be able to:

- ✅ Load base model in < 1 second
- ✅ Transcribe 10s audio in < 1.5s on M1
- ✅ Support 10+ languages
- ✅ Handle keep-warm for reduced latency
- ✅ Download models with progress
- ✅ Gracefully handle errors
- ✅ Work offline (no internet required)

**This will unlock the full Yapper experience!** 🎙️✨

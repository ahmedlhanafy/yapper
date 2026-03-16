import Foundation
import AVFoundation

/// Service for transcribing audio using Whisper
class WhisperService {
    static let shared = WhisperService()

    @Published var isTranscribing = false

    // Model management
    private var loadedModel: WhisperModel?
    private var modelKeepAliveTimer: Timer?
    private var bridge: WhisperBridge?

    private init() {
        // Initialize bridge
        bridge = WhisperBridge()
    }

    // MARK: - Transcription

    func transcribe(
        audioURL: URL,
        model: WhisperModel,
        language: String = "auto"
    ) async throws -> TranscriptionResult {
        guard !isTranscribing else {
            throw WhisperError.alreadyTranscribing
        }

        isTranscribing = true
        defer { isTranscribing = false }

        print("🎤 Transcribing with \(model.rawValue) model, language: \(language)")

        // Load model if needed
        if loadedModel != model {
            try await loadModel(model)
        }

        // Perform transcription
        // NOTE: This is a placeholder - actual implementation would call whisper.cpp
        let result = try await performTranscription(audioURL: audioURL, language: language)

        print("✓ Transcription complete: \(result.text.prefix(50))...")

        return result
    }

    // MARK: - Model Management

    private func loadModel(_ model: WhisperModel) async throws {
        print("📦 Loading \(model.rawValue) model...")

        // Check if model exists locally
        let modelURL = modelURL(for: model)
        if !FileManager.default.fileExists(atPath: modelURL.path) {
            throw WhisperError.modelNotFound(model)
        }

        // Load model using bridge
        try bridge?.loadModel(path: modelURL.path)

        loadedModel = model
        print("✓ Model loaded: \(model.rawValue)")
    }

    func preloadModel(_ model: WhisperModel, keepAliveDuration: TimeInterval? = nil) async throws {
        try await loadModel(model)

        // Setup keep-alive timer if specified
        if let duration = keepAliveDuration {
            modelKeepAliveTimer?.invalidate()
            modelKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.unloadModel()
            }
        }
    }

    func unloadModel() {
        guard loadedModel != nil else { return }

        // Unload model via bridge
        bridge?.unloadModel()

        loadedModel = nil
        modelKeepAliveTimer?.invalidate()
        modelKeepAliveTimer = nil

        print("🗑️ Model unloaded")
    }

    // MARK: - Model Downloads

    func downloadModel(_ model: WhisperModel, progress: @escaping (Double) -> Void) async throws {
        let modelURL = modelURL(for: model)

        // Check if already exists
        if FileManager.default.fileExists(atPath: modelURL.path) {
            print("ℹ️ Model already downloaded: \(model.rawValue)")
            return
        }

        print("⬇️ Downloading \(model.rawValue) model...")

        // TODO: Download from Hugging Face or OpenAI
        // For now, simulate download
        let downloadURL = modelDownloadURL(for: model)

        let (tempURL, _) = try await URLSession.shared.download(from: downloadURL) { bytesWritten, totalBytes, _ in
            if totalBytes > 0 {
                progress(Double(bytesWritten) / Double(totalBytes))
            }
        }

        // Move to models directory
        try FileManager.default.moveItem(at: tempURL, to: modelURL)

        print("✓ Model downloaded: \(model.rawValue)")
    }

    func isModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: modelURL(for: model).path)
    }

    func deleteModel(_ model: WhisperModel) throws {
        let modelURL = modelURL(for: model)

        if loadedModel == model {
            unloadModel()
        }

        try FileManager.default.removeItem(at: modelURL)
        print("✓ Model deleted: \(model.rawValue)")
    }

    // MARK: - Utilities

    private func modelURL(for model: WhisperModel) -> URL {
        let modelsDirectory = URL(fileURLWithPath: AppState.shared.settings.storageLocation)
            .appendingPathComponent("Models")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        return modelsDirectory.appendingPathComponent("ggml-\(model.rawValue).bin")
    }

    private func modelDownloadURL(for model: WhisperModel) -> URL {
        // Hugging Face repo: https://huggingface.co/ggerganov/whisper.cpp
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        return URL(string: "\(baseURL)/ggml-\(model.rawValue).bin")!
    }

    private func performTranscription(audioURL: URL, language: String) async throws -> TranscriptionResult {
        let startTime = Date()

        // Try real transcription first
        if let bridge = bridge {
            do {
                let result = try bridge.transcribe(
                    audioPath: audioURL.path,
                    language: language == "auto" ? "" : language
                )

                let processingTime = Date().timeIntervalSince(startTime)

                return TranscriptionResult(
                    text: result.text,
                    language: result.language,
                    segments: result.segments.map { segment in
                        TranscriptionSegment(
                            text: segment.text,
                            startTime: segment.startTime,
                            endTime: segment.endTime,
                            speaker: nil
                        )
                    },
                    processingTime: processingTime
                )
            } catch WhisperBridgeError.libraryNotAvailable {
                print("⚠️ Whisper library not available, using mock transcription")
                // Fall through to mock
            } catch {
                throw WhisperError.transcriptionFailed(error)
            }
        }

        // Fallback: Mock transcription for development/testing
        #if DEBUG
        print("ℹ️ Using mock transcription (Whisper.cpp not linked)")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate processing

        return TranscriptionResult(
            text: "This is a test transcription. Build and link whisper.cpp for real transcription.",
            language: language == "auto" ? "en" : language,
            segments: [],
            processingTime: 1.0
        )
        #else
        throw WhisperError.notImplemented
        #endif
    }

    // MARK: - Language Support

    static let supportedLanguages = [
        "auto": "Auto-detect",
        "en": "English",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "pt": "Portuguese",
        "nl": "Dutch",
        "ru": "Russian",
        "zh": "Chinese",
        "ja": "Japanese",
        "ko": "Korean",
        "ar": "Arabic",
        "hi": "Hindi",
        // Add more as needed - Whisper supports 100+
    ]
}

// MARK: - Types

struct TranscriptionResult {
    let text: String
    let language: String
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let speaker: String? // For diarization
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case alreadyTranscribing
    case modelNotFound(WhisperModel)
    case modelLoadFailed(Error)
    case transcriptionFailed(Error)
    case notImplemented
    case invalidAudioFormat

    var errorDescription: String? {
        switch self {
        case .alreadyTranscribing:
            return "Already transcribing another recording."
        case .modelNotFound(let model):
            return "Model '\(model.rawValue)' not found. Please download it first."
        case .modelLoadFailed(let error):
            return "Failed to load model: \(error.localizedDescription)"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        case .notImplemented:
            return "Whisper integration not yet implemented."
        case .invalidAudioFormat:
            return "Invalid audio format. Expected 16kHz mono WAV."
        }
    }
}

// MARK: - URLSession Extension

extension URLSession {
    func download(
        from url: URL,
        progressHandler: @escaping (Int64, Int64, Error?) -> Void
    ) async throws -> (URL, URLResponse) {
        let (asyncBytes, response) = try await bytes(from: url)

        let expectedLength = response.expectedContentLength
        var receivedLength: Int64 = 0

        // Create temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { try? fileHandle.close() }

        // Write bytes
        for try await byte in asyncBytes {
            let data = Data([byte])
            try fileHandle.write(contentsOf: data)
            receivedLength += 1

            if receivedLength % 1024 == 0 { // Update every KB
                progressHandler(receivedLength, expectedLength, nil)
            }
        }

        progressHandler(receivedLength, expectedLength, nil)

        return (tempURL, response)
    }
}

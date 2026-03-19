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
        let destURL = modelURL(for: model)

        if FileManager.default.fileExists(atPath: destURL.path) {
            print("ℹ️ Model already downloaded: \(model.rawValue)")
            return
        }

        let downloadURL = modelDownloadURL(for: model)
        print("⬇️ Downloading \(model.rawValue) from \(downloadURL)...")

        // Use URLSession download task with observation
        let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw WhisperError.modelLoadFailed(NSError(domain: "WhisperService", code: code, userInfo: [NSLocalizedDescriptionKey: "Download failed with status \(code)"]))
        }

        // Move to models directory
        // Remove existing file if any
        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)

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
        let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
        // The "large" model is "large-v3" on HuggingFace
        let filename: String
        switch model {
        case .large:
            filename = "ggml-large-v3.bin"
        default:
            filename = "ggml-\(model.rawValue).bin"
        }
        return URL(string: "\(baseURL)/\(filename)")!
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


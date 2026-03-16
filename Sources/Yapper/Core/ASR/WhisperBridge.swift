import Foundation
import AVFoundation

#if canImport(CWhisper)
import CWhisper
#endif

/// Swift wrapper for Whisper C API
class WhisperBridge {
    private var context: OpaquePointer?
    private let isAvailable: Bool

    init() {
        #if canImport(CWhisper)
        self.isAvailable = whisper_is_available() != 0
        #else
        self.isAvailable = false
        #endif
    }

    // MARK: - Model Management

    func loadModel(path: String) throws {
        #if canImport(CWhisper)
        guard isAvailable else {
            throw WhisperBridgeError.libraryNotAvailable
        }

        guard FileManager.default.fileExists(atPath: path) else {
            throw WhisperBridgeError.modelNotFound(path)
        }

        // Free existing context if any
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }

        // Load model
        guard let ctx = whisper_init_from_file(path) else {
            throw WhisperBridgeError.modelLoadFailed
        }

        context = ctx
        print("✓ Whisper model loaded: \(URL(fileURLWithPath: path).lastPathComponent)")
        #else
        throw WhisperBridgeError.libraryNotAvailable
        #endif
    }

    func unloadModel() {
        #if canImport(CWhisper)
        if let ctx = context {
            whisper_free(ctx)
            context = nil
            print("✓ Whisper model unloaded")
        }
        #endif
    }

    // MARK: - Transcription

    func transcribe(audioPath: String, language: String = "auto", nThreads: Int = 0) throws -> WhisperResult {
        #if canImport(CWhisper)
        guard isAvailable else {
            throw WhisperBridgeError.libraryNotAvailable
        }

        guard let ctx = context else {
            throw WhisperBridgeError.modelNotLoaded
        }

        // Load audio samples
        let samples = try loadAudioSamples(from: audioPath)

        // Perform transcription
        _ = ctx // Context used below
        return try transcribeSamples(samples, language: language, nThreads: nThreads)
        #else
        throw WhisperBridgeError.libraryNotAvailable
        #endif
    }

    func transcribeSamples(_ samples: [Float], language: String = "auto", nThreads: Int = 0) throws -> WhisperResult {
        #if canImport(CWhisper)
        guard isAvailable else {
            throw WhisperBridgeError.libraryNotAvailable
        }

        guard let ctx = context else {
            throw WhisperBridgeError.modelNotLoaded
        }

        // Setup parameters
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = nThreads > 0 ? Int32(nThreads) : Int32(ProcessInfo.processInfo.processorCount)
        params.translate = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false

        // Track if we allocated the language string ourselves
        var allocatedLanguagePtr: UnsafeMutablePointer<CChar>? = nil

        // Set language
        if language != "auto" && !language.isEmpty {
            allocatedLanguagePtr = strdup(language)
            params.language = UnsafePointer(allocatedLanguagePtr)
        }

        // Validate samples
        guard !samples.isEmpty else {
            // Free allocated language string before throwing
            if let ptr = allocatedLanguagePtr {
                free(ptr)
            }
            throw WhisperBridgeError.transcriptionFailed
        }

        print("🎤 Running whisper_full with \(samples.count) samples...")

        // Run transcription - need to pass pointer to samples
        let result = samples.withUnsafeBufferPointer { bufferPointer in
            whisper_full(ctx, params, bufferPointer.baseAddress, Int32(samples.count))
        }
        
        print("🎤 whisper_full returned: \(result)")

        // Free allocated language string (only if we allocated it)
        if let ptr = allocatedLanguagePtr {
            free(ptr)
        }

        guard result == 0 else {
            print("❌ whisper_full failed with code: \(result)")
            throw WhisperBridgeError.transcriptionFailed
        }

        // Extract results
        return try extractResult(from: ctx)
        #else
        throw WhisperBridgeError.libraryNotAvailable
        #endif
    }

    // MARK: - Audio Loading

    private func loadAudioSamples(from path: String) throws -> [Float] {
        let url = URL(fileURLWithPath: path)

        // Load audio file
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            throw WhisperBridgeError.audioLoadFailed
        }

        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw WhisperBridgeError.audioLoadFailed
        }

        try audioFile.read(into: buffer)

        // Convert to mono Float array
        return convertToMonoFloat(buffer: buffer)
    }

    private func convertToMonoFloat(buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var samples = [Float](repeating: 0, count: frameLength)

        if channelCount == 1 {
            // Already mono
            let channel = channelData[0]
            for i in 0..<frameLength {
                samples[i] = channel[i]
            }
        } else {
            // Convert to mono by averaging channels
            for i in 0..<frameLength {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                samples[i] = sum / Float(channelCount)
            }
        }

        return samples
    }

    // MARK: - Result Extraction

    private func extractResult(from context: OpaquePointer) throws -> WhisperResult {
        #if canImport(CWhisper)
        let nSegments = Int(whisper_full_n_segments(context))

        var fullText = ""
        var segments: [WhisperSegment] = []

        for i in 0..<nSegments {
            guard let segmentText = whisper_full_get_segment_text(context, Int32(i)) else {
                continue
            }

            let text = String(cString: segmentText)
            let t0 = whisper_full_get_segment_t0(context, Int32(i))
            let t1 = whisper_full_get_segment_t1(context, Int32(i))

            let segment = WhisperSegment(
                text: text,
                startTime: TimeInterval(t0) / 100.0, // Convert from centiseconds
                endTime: TimeInterval(t1) / 100.0
            )

            segments.append(segment)
            fullText += text
        }

        // Detect language
        let langId = Int(whisper_full_lang_id(context))
        let detectedLanguage = String(cString: whisper_lang_str(Int32(langId)))

        return WhisperResult(
            text: fullText.trimmingCharacters(in: .whitespacesAndNewlines),
            language: detectedLanguage,
            segments: segments
        )
        #else
        throw WhisperBridgeError.libraryNotAvailable
        #endif
    }

    deinit {
        unloadModel()
    }
}

// MARK: - Result Types

struct WhisperResult {
    let text: String
    let language: String
    let segments: [WhisperSegment]
}

struct WhisperSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

// MARK: - Errors

enum WhisperBridgeError: LocalizedError {
    case libraryNotAvailable
    case modelNotFound(String)
    case modelNotLoaded
    case modelLoadFailed
    case audioLoadFailed
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .libraryNotAvailable:
            return "Whisper library not available. Please build whisper.cpp and link it to the project."
        case .modelNotFound(let path):
            return "Model file not found at: \(path)"
        case .modelNotLoaded:
            return "No model loaded. Call loadModel() first."
        case .modelLoadFailed:
            return "Failed to load Whisper model. The model file may be corrupted."
        case .audioLoadFailed:
            return "Failed to load audio file. Ensure it's a valid audio format."
        case .transcriptionFailed:
            return "Whisper transcription failed."
        }
    }
}


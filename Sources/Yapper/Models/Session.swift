import Foundation

/// Represents a single dictation session with all its metadata
struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date

    // Audio
    var audioFilePath: String
    var duration: TimeInterval

    // Transcription
    var rawTranscript: String
    var language: String?

    // Processing
    var processedOutput: String?
    var mode: Mode
    var processingTime: TimeInterval?

    // Context (captured at time of recording)
    var capturedContext: CapturedContext?

    // AI details (for debugging/reprocessing)
    var aiPrompt: String?
    var aiProvider: String?
    var aiModel: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        audioFilePath: String,
        duration: TimeInterval,
        rawTranscript: String,
        language: String? = nil,
        processedOutput: String? = nil,
        mode: Mode,
        processingTime: TimeInterval? = nil,
        capturedContext: CapturedContext? = nil,
        aiPrompt: String? = nil,
        aiProvider: String? = nil,
        aiModel: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.audioFilePath = audioFilePath
        self.duration = duration
        self.rawTranscript = rawTranscript
        self.language = language
        self.processedOutput = processedOutput
        self.mode = mode
        self.processingTime = processingTime
        self.capturedContext = capturedContext
        self.aiPrompt = aiPrompt
        self.aiProvider = aiProvider
        self.aiModel = aiModel
    }

    var finalOutput: String {
        processedOutput ?? rawTranscript
    }
}

// MARK: - Captured Context

struct CapturedContext: Codable, Hashable {
    var clipboard: String?
    var selection: String?
    var activeApp: AppContext?
    var captureTimestamp: Date

    init(
        clipboard: String? = nil,
        selection: String? = nil,
        activeApp: AppContext? = nil,
        captureTimestamp: Date = Date()
    ) {
        self.clipboard = clipboard
        self.selection = selection
        self.activeApp = activeApp
        self.captureTimestamp = captureTimestamp
    }
}

struct AppContext: Codable, Hashable {
    var bundleId: String
    var name: String
    var windowTitle: String?
    var url: String? // For browsers

    init(
        bundleId: String,
        name: String,
        windowTitle: String? = nil,
        url: String? = nil
    ) {
        self.bundleId = bundleId
        self.name = name
        self.windowTitle = windowTitle
        self.url = url
    }
}

// MARK: - Session Search

extension Session {
    func matches(searchText: String) -> Bool {
        let lowercased = searchText.lowercased()
        return rawTranscript.lowercased().contains(lowercased) ||
               processedOutput?.lowercased().contains(lowercased) == true ||
               mode.name.lowercased().contains(lowercased)
    }
}

import Foundation

/// Represents a dictation mode with voice and AI processing settings
struct Mode: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var key: String // Stable identifier for automation
    var isBuiltIn: Bool

    // Voice settings
    var voiceSettings: VoiceSettings

    // AI processing
    var aiEnabled: Bool
    var aiSettings: AISettings?

    // Context capture
    var contextSettings: ContextSettings

    // Auto-activation
    var autoActivation: AutoActivation?

    // Output behavior
    var outputBehavior: OutputBehavior

    init(
        id: UUID = UUID(),
        name: String,
        key: String,
        isBuiltIn: Bool = false,
        voiceSettings: VoiceSettings = VoiceSettings(),
        aiEnabled: Bool = false,
        aiSettings: AISettings? = nil,
        contextSettings: ContextSettings = ContextSettings(),
        autoActivation: AutoActivation? = nil,
        outputBehavior: OutputBehavior = .insertAtCursor
    ) {
        self.id = id
        self.name = name
        self.key = key
        self.isBuiltIn = isBuiltIn
        self.voiceSettings = voiceSettings
        self.aiEnabled = aiEnabled
        self.aiSettings = aiSettings
        self.contextSettings = contextSettings
        self.autoActivation = autoActivation
        self.outputBehavior = outputBehavior
    }
}

// MARK: - Voice Settings

struct VoiceSettings: Codable, Equatable, Hashable {
    var language: String // ISO code, e.g. "en", "es", "auto"
    var model: WhisperModel
    var keepWarmDuration: TimeInterval? // nil = don't keep warm

    init(
        language: String = "auto",
        model: WhisperModel = .base,
        keepWarmDuration: TimeInterval? = nil
    ) {
        self.language = language
        self.model = model
        self.keepWarmDuration = keepWarmDuration
    }
}

enum WhisperModel: String, Codable, CaseIterable {
    case tiny
    case base
    case small
    case medium
    case large

    var displayName: String {
        rawValue.capitalized
    }

    var estimatedSize: String {
        switch self {
        case .tiny: return "75 MB"
        case .base: return "142 MB"
        case .small: return "466 MB"
        case .medium: return "1.5 GB"
        case .large: return "2.9 GB"
        }
    }
}

// MARK: - AI Settings

struct AISettings: Codable, Equatable, Hashable {
    var provider: AIProvider
    var model: String
    var instructions: String
    var translateToEnglish: Bool

    init(
        provider: AIProvider = .openai,
        model: String = "gpt-4",
        instructions: String = "",
        translateToEnglish: Bool = false
    ) {
        self.provider = provider
        self.model = model
        self.instructions = instructions
        self.translateToEnglish = translateToEnglish
    }
}

enum AIProvider: String, Codable, CaseIterable {
    case openai
    case anthropic
    case local

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .local: return "Local Model"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4"
        case .anthropic: return "claude-3-5-sonnet-20241022"
        case .local: return "llama-3"
        }
    }
}

// MARK: - Context Settings

struct ContextSettings: Codable, Equatable, Hashable {
    var captureClipboard: Bool
    var captureSelection: Bool
    var captureAppContext: Bool

    init(
        captureClipboard: Bool = false,
        captureSelection: Bool = false,
        captureAppContext: Bool = false
    ) {
        self.captureClipboard = captureClipboard
        self.captureSelection = captureSelection
        self.captureAppContext = captureAppContext
    }
}

// MARK: - Auto Activation

struct AutoActivation: Codable, Equatable, Hashable {
    var apps: [String] // Bundle IDs
    var websites: [String] // URL patterns

    init(apps: [String] = [], websites: [String] = []) {
        self.apps = apps
        self.websites = websites
    }
}

// MARK: - Output Behavior

enum OutputBehavior: String, Codable {
    case insertAtCursor
    case copyToClipboard
    case both
}

// MARK: - Built-in Modes

extension Mode {
    static let voiceToText = Mode(
        name: "Voice to Text",
        key: "voice-to-text",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: false,
        outputBehavior: .insertAtCursor
    )

    static let email = Mode(
        name: "Email",
        key: "email",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: true,
        aiSettings: AISettings(
            provider: .openai,
            model: "gpt-4",
            instructions: """
            Transform the transcribed voice message into a professional email.
            - Use proper greeting and closing
            - Organize into clear paragraphs
            - Maintain professional tone
            - Fix grammar and punctuation
            - Preserve the core message and intent
            """
        ),
        outputBehavior: .insertAtCursor
    )

    static let message = Mode(
        name: "Message",
        key: "message",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: true,
        aiSettings: AISettings(
            provider: .openai,
            model: "gpt-4",
            instructions: """
            Transform the transcribed voice message into a casual, friendly message.
            - Keep it conversational and natural
            - Fix obvious grammar issues but maintain casual tone
            - Remove filler words (um, uh, like)
            - Keep it concise
            """
        ),
        outputBehavior: .insertAtCursor
    )

    static let note = Mode(
        name: "Note",
        key: "note",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: true,
        aiSettings: AISettings(
            provider: .openai,
            model: "gpt-4",
            instructions: """
            Transform the transcribed voice into organized notes.
            - Create bullet points or numbered lists when appropriate
            - Group related ideas together
            - Clean up grammar and punctuation
            - Preserve all key information
            - Use clear, concise language
            """
        ),
        outputBehavior: .insertAtCursor
    )

    static let meeting = Mode(
        name: "Meeting",
        key: "meeting",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: true,
        aiSettings: AISettings(
            provider: .openai,
            model: "gpt-4",
            instructions: """
            Transform the meeting transcription into structured meeting notes.
            - Extract key decisions and action items
            - Identify main discussion points
            - Note any deadlines or commitments
            - Organize chronologically or by topic
            - Highlight important takeaways
            """
        ),
        contextSettings: ContextSettings(
            captureClipboard: false,
            captureSelection: false,
            captureAppContext: false
        ),
        outputBehavior: .copyToClipboard
    )

    static let superMode = Mode(
        name: "Super",
        key: "super",
        isBuiltIn: true,
        voiceSettings: VoiceSettings(language: "auto", model: .base),
        aiEnabled: true,
        aiSettings: AISettings(
            provider: .openai,
            model: "gpt-4",
            instructions: """
            You are a context-aware text transformation assistant.

            If selected text is provided, apply formatting commands:
            - "title case" / "capitalize" → Title Case
            - "uppercase" / "all caps" → UPPERCASE
            - "lowercase" → lowercase
            - "bullets" / "bullet points" → Convert to bullet list

            Otherwise, adapt the transcribed text based on:
            - The active application (email client, messenger, notes, code editor, etc.)
            - Any clipboard or selection context provided
            - Preserve intent while matching the expected format for that app
            - Fix spelling using app-specific vocabulary
            - Format URLs and emails appropriately
            """
        ),
        contextSettings: ContextSettings(
            captureClipboard: true,
            captureSelection: true,
            captureAppContext: true
        ),
        outputBehavior: .insertAtCursor
    )

    static var allBuiltIn: [Mode] {
        [voiceToText, email, message, note, meeting, superMode]
    }
}

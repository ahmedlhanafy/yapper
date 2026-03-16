import Foundation

/// App appearance mode
enum AppearanceMode: String, Codable, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

/// Recording window style
enum RecordingWindowStyle: String, Codable, CaseIterable {
    case classic = "classic"
    case mini = "mini"

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .mini: return "Mini"
        }
    }
}

/// App-wide settings
struct Settings: Codable {
    // General
    var startAtLogin: Bool
    var showMiniWindow: Bool
    var storageLocation: String // Path to config/data folder
    var appearanceMode: AppearanceMode
    var recordingWindowStyle: RecordingWindowStyle

    // Shortcuts
    var recordingHotkey: Hotkey?
    var cycleModeHotkey: Hotkey?

    // Audio
    var inputDevice: String? // Device ID, nil = default
    var enableNormalization: Bool
    var recordOnMenubarClick: Bool // true = toggle, false = show menu

    // Modes
    var modes: [Mode]
    var defaultModeKey: String

    // API Keys (stored in Keychain, these are just flags)
    var hasOpenAIKey: Bool
    var hasAnthropicKey: Bool

    // Privacy
    var enableTelemetry: Bool

    init() {
        self.startAtLogin = false
        self.showMiniWindow = false
        self.storageLocation = Self.defaultStorageLocation()
        self.appearanceMode = .system
        self.recordingWindowStyle = .classic

        self.recordingHotkey = Hotkey(keyCode: 49, modifiers: [.option]) // Option+Space
        self.cycleModeHotkey = Hotkey(keyCode: 43, modifiers: [.command, .shift]) // Cmd+Shift+,

        self.inputDevice = nil
        self.enableNormalization = true
        self.recordOnMenubarClick = true

        self.modes = Mode.allBuiltIn
        self.defaultModeKey = Mode.voiceToText.key

        self.hasOpenAIKey = false
        self.hasAnthropicKey = false

        self.enableTelemetry = false
    }

    static func defaultStorageLocation() -> String {
        // Use Application Support instead of Documents to avoid permission dialogs
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Yapper").path
    }

    var currentMode: Mode? {
        modes.first { $0.key == defaultModeKey }
    }

    mutating func updateMode(_ mode: Mode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
        }
    }

    mutating func addMode(_ mode: Mode) {
        modes.append(mode)
    }

    mutating func deleteMode(_ mode: Mode) {
        modes.removeAll { $0.id == mode.id }
    }
}

// MARK: - Hotkey

struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: [KeyModifier]

    var displayString: String {
        let modifierStrings = modifiers.map { $0.symbol }.joined()
        let keyString = KeyCodeMapper.string(for: keyCode) ?? "?"
        return modifierStrings + keyString
    }
}

enum KeyModifier: String, Codable {
    case command
    case option
    case control
    case shift

    var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }

    var carbonFlag: UInt32 {
        switch self {
        case .command: return 0x0100 // cmdKey
        case .option: return 0x0800 // optionKey
        case .control: return 0x1000 // controlKey
        case .shift: return 0x0200 // shiftKey
        }
    }
}

// MARK: - Key Code Mapper

struct KeyCodeMapper {
    static func string(for keyCode: UInt16) -> String? {
        let mapping: [UInt16: String] = [
            49: "Space",
            36: "Return",
            48: "Tab",
            51: "Delete",
            53: "Escape",
            // Letters
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
            7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W",
            14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
            34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
            // Numbers
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6",
            26: "7", 28: "8", 25: "9", 29: "0",
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5",
            97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
            // Symbols
            43: ",", 47: ".", 44: "/", 41: ";", 39: "'",
            50: "`", 27: "-", 24: "=", 33: "[", 30: "]", 42: "\\"
        ]
        return mapping[keyCode]
    }
}

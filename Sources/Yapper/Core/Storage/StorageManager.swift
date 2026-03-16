import Foundation

/// Manages persistent storage of settings, modes, and history
class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Default storage location (avoids circular dependency with AppState)
    private let defaultStorageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Yapper")
    }()

    private var storageURL: URL {
        defaultStorageURL
    }

    private var settingsURL: URL {
        defaultStorageURL.appendingPathComponent("settings.json")
    }

    private var historyURL: URL {
        defaultStorageURL.appendingPathComponent("history.json")
    }

    private var recordingsURL: URL {
        defaultStorageURL.appendingPathComponent("Recordings")
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601

        setupStorageDirectory()
    }

    // MARK: - Setup

    private func setupStorageDirectory() {
        let baseURL = defaultStorageURL
        let directories = [
            baseURL,
            baseURL.appendingPathComponent("Recordings"),
            baseURL.appendingPathComponent("Models")
        ]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                    print("✓ Created directory: \(directory.lastPathComponent)")
                } catch {
                    print("⚠️ Failed to create directory: \(error)")
                }
            }
        }
    }

    // MARK: - Settings

    func saveSettings(_ settings: Settings) {
        do {
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
            print("✓ Settings saved")
        } catch {
            print("⚠️ Failed to save settings: \(error)")
        }
    }

    func loadSettings() -> Settings? {
        guard fileManager.fileExists(atPath: settingsURL.path) else {
            print("ℹ️ No settings file found, using defaults")
            return nil
        }

        do {
            let data = try Data(contentsOf: settingsURL)
            let settings = try decoder.decode(Settings.self, from: data)
            print("✓ Settings loaded")
            return settings
        } catch {
            print("⚠️ Failed to load settings: \(error)")
            return nil
        }
    }

    // MARK: - History

    private var historyCache: [Session] = []
    private var historyCacheLoaded = false

    func saveSession(_ session: Session) {
        // Load history if not already loaded
        if !historyCacheLoaded {
            historyCache = loadHistory()
            historyCacheLoaded = true
        }

        // Add to cache
        historyCache.insert(session, at: 0) // Most recent first

        // Keep only last 1000 sessions
        if historyCache.count > 1000 {
            historyCache = Array(historyCache.prefix(1000))
        }

        // Save to disk
        do {
            let data = try encoder.encode(historyCache)
            try data.write(to: historyURL, options: .atomic)
            print("✓ Session saved to history")
        } catch {
            print("⚠️ Failed to save session: \(error)")
        }
    }

    func loadHistory() -> [Session] {
        guard fileManager.fileExists(atPath: historyURL.path) else {
            print("ℹ️ No history file found")
            return []
        }

        do {
            let data = try Data(contentsOf: historyURL)
            let sessions = try decoder.decode([Session].self, from: data)
            print("✓ Loaded \(sessions.count) sessions from history")
            return sessions
        } catch {
            print("⚠️ Failed to load history: \(error)")
            return []
        }
    }

    func searchHistory(query: String) -> [Session] {
        if !historyCacheLoaded {
            historyCache = loadHistory()
            historyCacheLoaded = true
        }

        if query.isEmpty {
            return historyCache
        }

        return historyCache.filter { $0.matches(searchText: query) }
    }

    func deleteSession(_ sessionID: UUID) {
        if !historyCacheLoaded {
            historyCache = loadHistory()
            historyCacheLoaded = true
        }

        historyCache.removeAll { $0.id == sessionID }

        do {
            let data = try encoder.encode(historyCache)
            try data.write(to: historyURL, options: .atomic)
            print("✓ Session deleted")
        } catch {
            print("⚠️ Failed to delete session: \(error)")
        }
    }

    // MARK: - Audio Files

    func deleteAudioFile(at path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            try fileManager.removeItem(at: url)
            print("✓ Audio file deleted")
        } catch {
            print("⚠️ Failed to delete audio file: \(error)")
        }
    }

    // MARK: - Backup & Export

    func exportData(to destinationURL: URL) throws {
        // Copy entire storage directory
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: storageURL, to: destinationURL)
        print("✓ Data exported to: \(destinationURL.path)")
    }

    func importData(from sourceURL: URL) throws {
        // Backup current data first
        let backupURL = storageURL.appendingPathExtension("backup_\(Date().timeIntervalSince1970)")
        if fileManager.fileExists(atPath: storageURL.path) {
            try fileManager.moveItem(at: storageURL, to: backupURL)
        }

        // Import new data
        try fileManager.copyItem(at: sourceURL, to: storageURL)

        // Reload settings
        if let settings = loadSettings() {
            AppState.shared.settings = settings
        }

        // Clear history cache to force reload
        historyCacheLoaded = false
        historyCache = []

        print("✓ Data imported from: \(sourceURL.path)")
        print("ℹ️ Backup saved to: \(backupURL.path)")
    }

    func getStorageSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: storageURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        totalSize += fileSize
                    }
                } catch {
                    continue
                }
            }
        }

        return totalSize
    }

    func formatStorageSize() -> String {
        let size = getStorageSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Keychain (for API keys)

extension StorageManager {
    private var keychainService: String { "com.yapper.apikeys" }

    func saveAPIKey(_ key: String, for provider: AIProvider) {
        let account = provider.rawValue

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: key.data(using: .utf8)!
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            print("✓ API key saved for \(provider.displayName)")
        } else {
            print("⚠️ Failed to save API key: \(status)")
        }
    }

    func loadAPIKey(for provider: AIProvider) -> String? {
        let account = provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8) {
            return key
        }

        return nil
    }

    func deleteAPIKey(for provider: AIProvider) {
        let account = provider.rawValue

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
        print("✓ API key deleted for \(provider.displayName)")
    }
}

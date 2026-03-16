import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Tab? = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case modes = "Modes"
        case audio = "Audio"
        case apiKeys = "API Keys"
        case advanced = "Advanced"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "keyboard"
            case .modes: return "sparkles"
            case .audio: return "waveform"
            case .apiKeys: return "key"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            if let tab = selectedTab {
                contentView(for: tab)
                    .navigationTitle(tab.rawValue)
            } else {
                Text("Select a category")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 650, minHeight: 500)
    }

    @ViewBuilder
    private func contentView(for tab: Tab) -> some View {
        switch tab {
        case .general:
            GeneralSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .modes:
            ModesSettingsView()
        case .audio:
            AudioSettingsView()
        case .apiKeys:
            APIKeysSettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Start at login", isOn: $appState.settings.startAtLogin)
            }

            Section("Interface") {
                Picker("Appearance", selection: Binding(
                    get: { appState.settings.appearanceMode },
                    set: { mode in
                        appState.settings.appearanceMode = mode
                        appState.saveSettings()
                        AppearanceManager.shared.applyAppearance(mode)
                    }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Record on menubar click", isOn: $appState.settings.recordOnMenubarClick)
                    .help("When enabled, clicking the menubar icon starts/stops recording. Right-click for menu.")
            }

            Section("Recording Window") {
                RecordingWindowStylePicker(
                    selection: Binding(
                        get: { appState.settings.recordingWindowStyle },
                        set: { style in
                            appState.settings.recordingWindowStyle = style
                            appState.saveSettings()
                        }
                    )
                )
            }

            Section("Storage") {
                HStack {
                    Text("Location:")
                    Text(appState.settings.storageLocation)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change...") {
                        // TODO: File picker
                    }
                }

                HStack {
                    Text("Size:")
                    Text(StorageManager.shared.formatStorageSize())
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        Form {
            Section("Hotkeys") {
                HotkeyRecorderView(
                    title: "Start/Stop Recording:",
                    hotkey: Binding(
                        get: { appState.settings.recordingHotkey },
                        set: { newValue in
                            appState.settings.recordingHotkey = newValue
                            appState.saveSettings()

                            // Re-register hotkeys
                            HotkeyManager.shared.unregisterAll()
                            HotkeyManager.shared.registerDefaultHotkeys()
                        }
                    )
                )

                HotkeyRecorderView(
                    title: "Cycle Modes:",
                    hotkey: Binding(
                        get: { appState.settings.cycleModeHotkey },
                        set: { newValue in
                            appState.settings.cycleModeHotkey = newValue
                            appState.saveSettings()

                            // Re-register hotkeys
                            HotkeyManager.shared.unregisterAll()
                            HotkeyManager.shared.registerDefaultHotkeys()
                        }
                    )
                )
            }

            Section {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Hotkeys work globally, even when Yapper is in the background.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Modes Settings

struct ModesSettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedModeID: UUID?
    @State private var showingModeEditor = false
    @State private var modeToEdit: Mode?
    @State private var showingDeleteConfirmation = false

    private var selectedMode: Mode? {
        guard let id = selectedModeID else { return nil }
        return appState.settings.modes.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(appState.settings.modes, id: \.id, selection: $selectedModeID) { mode in
                HStack {
                    VStack(alignment: .leading) {
                        Text(mode.name)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Text(mode.aiEnabled ? "AI Enabled" : "Voice Only")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if mode.contextSettings.captureClipboard ||
                               mode.contextSettings.captureSelection ||
                               mode.contextSettings.captureAppContext {
                                Text("• Context-aware")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Spacer()

                    if mode.isBuiltIn {
                        Text("Built-in")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                .tag(mode.id)
            }

            Divider()

            HStack {
                Button(action: createNewMode) {
                    Label("New Mode", systemImage: "plus")
                }

                if let selected = selectedMode {
                    Button(action: { editMode(selected) }) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(action: { duplicateMode(selected) }) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }

                    Button(action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selected.isBuiltIn)
                    .tint(.red)
                }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingModeEditor) {
            ModeEditorView(mode: modeToEdit)
        }
        .alert("Delete Mode", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let mode = selectedMode {
                    deleteMode(mode)
                }
            }
        } message: {
            if let mode = selectedMode {
                Text("Are you sure you want to delete '\(mode.name)'? This action cannot be undone.")
            }
        }
    }

    private func createNewMode() {
        modeToEdit = nil
        showingModeEditor = true
    }

    private func editMode(_ mode: Mode) {
        modeToEdit = mode
        showingModeEditor = true
    }

    private func duplicateMode(_ mode: Mode) {
        let newMode = Mode(
            id: UUID(),
            name: "\(mode.name) (Copy)",
            key: "custom-\(UUID().uuidString.prefix(8))",
            isBuiltIn: false,
            voiceSettings: mode.voiceSettings,
            aiEnabled: mode.aiEnabled,
            aiSettings: mode.aiSettings,
            contextSettings: mode.contextSettings,
            autoActivation: mode.autoActivation,
            outputBehavior: mode.outputBehavior
        )

        appState.settings.addMode(newMode)
        appState.saveSettings()
        selectedModeID = newMode.id

        print("✓ Duplicated mode: \(newMode.name)")
    }

    private func deleteMode(_ mode: Mode) {
        guard !mode.isBuiltIn else { return }

        appState.settings.deleteMode(mode)
        appState.saveSettings()
        selectedModeID = nil

        print("✓ Deleted mode: \(mode.name)")
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared

    var body: some View {
        Form {
            Section("Input") {
                Picker("Microphone:", selection: $appState.settings.inputDevice) {
                    Text("Default").tag(nil as String?)

                    ForEach(audioEngine.availableInputDevices(), id: \.id) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }

                Toggle("Enable audio normalization", isOn: $appState.settings.enableNormalization)
                    .help("Automatically adjust volume levels for consistent transcription quality")
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: audioEngine.permissionStatus == .granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(audioEngine.permissionStatus == .granted ? .green : .red)

                    Text("Microphone Access:")
                    Text(audioEngine.permissionStatus == .granted ? "Granted" : "Not Granted")
                        .foregroundColor(.secondary)

                    Spacer()

                    if audioEngine.permissionStatus != .granted {
                        Button("Request") {
                            audioEngine.requestPermissions()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - API Keys Settings

struct APIKeysSettingsView: View {
    @State private var openaiKey = ""
    @State private var anthropicKey = ""
    @State private var showingSaved = false

    var body: some View {
        Form {
            Section("OpenAI") {
                SecureField("API Key", text: $openaiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        StorageManager.shared.saveAPIKey(openaiKey, for: .openai)
                        showingSaved = true
                    }
                    .disabled(openaiKey.isEmpty)

                    Button("Clear") {
                        StorageManager.shared.deleteAPIKey(for: .openai)
                        openaiKey = ""
                    }
                }
            }

            Section("Anthropic") {
                SecureField("API Key", text: $anthropicKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        StorageManager.shared.saveAPIKey(anthropicKey, for: .anthropic)
                        showingSaved = true
                    }
                    .disabled(anthropicKey.isEmpty)

                    Button("Clear") {
                        StorageManager.shared.deleteAPIKey(for: .anthropic)
                        anthropicKey = ""
                    }
                }
            }

            Section {
                Text("API keys are stored securely in the macOS Keychain.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .alert("Keys Saved", isPresented: $showingSaved) {
            Button("OK") { }
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModelManagerView()

                Divider()

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy")
                            .font(.headline)

                        Toggle("Enable telemetry", isOn: $appState.settings.enableTelemetry)
                            .help("Help improve Yapper by sending anonymous usage data")

                        Text("Telemetry helps us understand how Yapper is used and improve the app. No personal data or recordings are sent.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Data Management")
                            .font(.headline)

                        HStack {
                            Text("Storage Size:")
                            Text(StorageManager.shared.formatStorageSize())
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)

                        HStack(spacing: 12) {
                            Button("Export Data...") {
                                exportData()
                            }

                            Button("Import Data...") {
                                importData()
                            }
                        }

                        Text("Export includes settings, modes, and history. Audio recordings are not exported by default.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Yapper-Backup-\(Date().ISO8601Format()).yapper"
        panel.allowedContentTypes = [.data]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try StorageManager.shared.exportData(to: url)
                print("✓ Data exported successfully")
            } catch {
                print("❌ Export failed: \(error)")
            }
        }
    }

    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }

            do {
                try StorageManager.shared.importData(from: url)
                print("✓ Data imported successfully")
            } catch {
                print("❌ Import failed: \(error)")
            }
        }
    }
}

// MARK: - Recording Window Style Picker

struct RecordingWindowStylePicker: View {
    @Binding var selection: RecordingWindowStyle
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Style")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(RecordingWindowStyle.allCases, id: \.self) { style in
                    StyleOptionButton(
                        style: style,
                        isSelected: selection == style,
                        colorScheme: colorScheme
                    ) {
                        selection = style
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct StyleOptionButton: View {
    let style: RecordingWindowStyle
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Style preview icon
                stylePreview
                    .frame(width: 80, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                Text(style.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stylePreview: some View {
        switch style {
        case .classic:
            // Classic style preview - larger window with waveform
            HStack(spacing: 1) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                        .frame(width: 2, height: CGFloat.random(in: 4...16))
                }
            }

        case .mini:
            // Mini style preview - small pill with few bars
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 4, height: 4)

                HStack(spacing: 1) {
                    ForEach(0..<6, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.4))
                            .frame(width: 1.5, height: CGFloat.random(in: 3...8))
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 700, height: 600)
}

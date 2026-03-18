import SwiftUI
import AVFoundation

// Shared state between sidebar and detail
class SettingsViewState: ObservableObject {
    @Published var selectedTab: SettingsView.Tab?

    init(tab: SettingsView.Tab = .general) {
        self.selectedTab = tab
    }
}

// Namespace for Tab enum and convenience
enum SettingsView {
    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case modes = "Modes"
        case audio = "Audio"
        case apiKeys = "API Keys"
        case advanced = "Advanced"
        case history = "History"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .shortcuts: return "keyboard.fill"
            case .modes: return "sparkles"
            case .audio: return "waveform"
            case .apiKeys: return "key.fill"
            case .advanced: return "slider.horizontal.3"
            case .history: return "clock.arrow.circlepath"
            }
        }

        var iconGradient: LinearGradient {
            return LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.55, alpha: 1.0)),
                    Color(nsColor: NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.4, alpha: 1.0))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// Sidebar view (left pane)
struct SettingsSidebarView: View {
    @ObservedObject var viewState: SettingsViewState

    var body: some View {
        List(SettingsView.Tab.allCases, selection: $viewState.selectedTab) { tab in
            Label {
                Text(tab.rawValue)
            } icon: {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(tab.iconGradient)
                    )
            }
            .tag(tab)
        }
        .listStyle(.sidebar)
        .tint(Color(nsColor: NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.38, alpha: 1.0)))
    }
}

// Detail view (right pane)
struct SettingsDetailView: View {
    @ObservedObject var viewState: SettingsViewState

    var body: some View {
        Group {
            if let tab = viewState.selectedTab {
                contentView(for: tab)
            } else {
                Text("Select a category")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func contentView(for tab: SettingsView.Tab) -> some View {
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
        case .history:
            HistoryView()
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
                Toggle("Show in Dock", isOn: Binding(
                    get: { appState.settings.showInDock },
                    set: { show in
                        appState.settings.showInDock = show
                        appState.saveSettings()
                        NSApp.setActivationPolicy(show ? .regular : .accessory)
                    }
                ))
                .help("Show Yapper icon in the Dock. When hidden, use the menubar icon.")
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

                Toggle("Show toast notifications", isOn: $appState.settings.showToastNotifications)
                    .help("Show popup notifications for events like errors, blank audio, and text insertion.")
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
    @State private var modeToEdit: Mode?
    @State private var showingNewModeEditor = false
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
        .sheet(item: $modeToEdit) { mode in
            ModeEditorView(mode: mode)
        }
        .sheet(isPresented: $showingNewModeEditor) {
            ModeEditorView()
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
        showingNewModeEditor = true
    }

    private func editMode(_ mode: Mode) {
        modeToEdit = mode
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
    @State private var devices: [(id: String, name: String)] = []
    @State private var permissionGranted = false
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Input") {
                Picker("Microphone:", selection: $appState.settings.inputDevice) {
                    Text("Default").tag(nil as String?)

                    ForEach(devices, id: \.id) { device in
                        Text(device.name).tag(device.id as String?)
                    }
                }

                Toggle("Enable audio normalization", isOn: $appState.settings.enableNormalization)
                    .help("Automatically adjust volume levels for consistent transcription quality")
            }

            Section("Permissions") {
                HStack {
                    Image(systemName: permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(permissionGranted ? .green : .red)

                    Text("Microphone Access:")
                    Text(permissionGranted ? "Granted" : "Not Granted")
                        .foregroundColor(.secondary)

                    Spacer()

                    if !permissionGranted {
                        Button("Request") {
                            AudioEngine.shared.requestPermissions()
                            permissionGranted = AudioEngine.shared.permissionStatus == .granted
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            permissionGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            DispatchQueue.global(qos: .userInitiated).async {
                let found = AudioEngine.shared.availableInputDevices()
                DispatchQueue.main.async {
                    devices = found
                }
            }
        }
    }
}

// MARK: - API Keys Settings

struct APIKeysSettingsView: View {
    @State private var openaiKey = ""
    @State private var anthropicKey = ""
    @ObservedObject private var ollama = OllamaService.shared
    @ObservedObject private var appState = AppState.shared

    private var hasOpenAIKey: Bool { StorageManager.shared.loadAPIKey(for: .openai) != nil }
    private var hasAnthropicKey: Bool { StorageManager.shared.loadAPIKey(for: .anthropic) != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // OpenAI
                ProviderCard(
                    name: "OpenAI",
                    icon: "brain",
                    color: .green,
                    isConnected: hasOpenAIKey,
                    description: "GPT-4 and other OpenAI models"
                ) {
                    HStack(spacing: 8) {
                        SecureField("sk-...", text: $openaiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        Button(hasOpenAIKey ? "Update" : "Save") {
                            StorageManager.shared.saveAPIKey(openaiKey, for: .openai)
                            openaiKey = ""
                        }
                        .disabled(openaiKey.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        if hasOpenAIKey {
                            Button("Remove") {
                                StorageManager.shared.deleteAPIKey(for: .openai)
                                openaiKey = ""
                            }
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                }

                // Anthropic
                ProviderCard(
                    name: "Anthropic",
                    icon: "sparkle",
                    color: .orange,
                    isConnected: hasAnthropicKey,
                    description: "Claude and other Anthropic models"
                ) {
                    HStack(spacing: 8) {
                        SecureField("sk-ant-...", text: $anthropicKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))

                        Button(hasAnthropicKey ? "Update" : "Save") {
                            StorageManager.shared.saveAPIKey(anthropicKey, for: .anthropic)
                            anthropicKey = ""
                        }
                        .disabled(anthropicKey.isEmpty)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        if hasAnthropicKey {
                            Button("Remove") {
                                StorageManager.shared.deleteAPIKey(for: .anthropic)
                                anthropicKey = ""
                            }
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                }

                // Ollama
                ProviderCard(
                    name: "Ollama",
                    icon: "desktopcomputer",
                    color: .blue,
                    isConnected: ollama.isRunning,
                    description: "Run models locally on your Mac"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        if ollama.isRunning && !ollama.availableModels.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(ollama.availableModels.enumerated()), id: \.element.id) { index, model in
                                    HStack {
                                        Text(model.name)
                                            .font(.system(size: 12, design: .monospaced))
                                        Spacer()
                                        Text(ByteCountFormatter.string(fromByteCount: model.size, countStyle: .file))
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    if index < ollama.availableModels.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                            .cornerRadius(6)
                        } else if !ollama.isRunning {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("Start Ollama to use local models.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Link("Get Ollama", destination: URL(string: "https://ollama.com")!)
                                    .font(.system(size: 12))
                            }
                        }

                        HStack(spacing: 8) {
                            Text("URL")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            TextField("http://localhost:11434", text: $appState.settings.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            Button {
                                Task { await ollama.checkStatus() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .controlSize(.small)
                            .disabled(ollama.isChecking)
                        }
                    }
                }

                // Footer
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("API keys are stored in the macOS Keychain.")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }
            .padding(20)
        }
        .onAppear {
            Task { await ollama.checkStatus() }
        }
    }
}

struct ProviderCard<Content: View>: View {
    let name: String
    let icon: String
    let color: Color
    let isConnected: Bool
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7).fill(color))

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: .semibold))
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color(nsColor: .separatorColor))
                        .frame(width: 7, height: 7)
                    Text(isConnected ? "Connected" : "Not connected")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            content
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
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
                        Text("Developer")
                            .font(.headline)

                        Toggle("Demo Mode", isOn: Binding(
                            get: { appState.settings.demoMode },
                            set: { enabled in
                                appState.settings.demoMode = enabled
                                appState.saveSettings()
                                if enabled {
                                    MiniRecordingWindowController.shared.show()
                                } else {
                                    MiniRecordingWindowController.shared.hide()
                                }
                            }
                        ))
                        .help("Show recording window with animated waveform for screenshots")

                        Text("Shows the recording window with a pulsing waveform. Useful for taking screenshots and demos.")
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
    SettingsDetailView(viewState: SettingsViewState(tab: .general))
        .frame(width: 700, height: 600)
}

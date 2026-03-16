import SwiftUI

/// Editor for creating/editing custom modes
struct ModeEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var appState = AppState.shared

    @State private var mode: Mode
    @State private var isNew: Bool
    @State private var showingValidationError = false
    @State private var validationMessage = ""

    init(mode: Mode? = nil) {
        if let existingMode = mode {
            _mode = State(initialValue: existingMode)
            _isNew = State(initialValue: false)
        } else {
            // Create new mode template
            _mode = State(initialValue: Mode(
                name: "New Mode",
                key: "custom-\(UUID().uuidString.prefix(8))",
                isBuiltIn: false,
                voiceSettings: VoiceSettings(),
                aiEnabled: false,
                contextSettings: ContextSettings(),
                outputBehavior: .insertAtCursor
            ))
            _isNew = State(initialValue: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isNew ? "Create Mode" : "Edit Mode")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button(isNew ? "Create" : "Save") {
                    saveMode()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Basic Information")
                                .font(.headline)

                            TextField("Mode Name", text: $mode.name)
                                .textFieldStyle(.roundedBorder)

                            if mode.isBuiltIn {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.blue)
                                    Text("Built-in mode (customizable)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    // Voice Settings
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Voice Recognition")
                                .font(.headline)

                            Picker("Language", selection: $mode.voiceSettings.language) {
                                ForEach(Array(WhisperService.supportedLanguages.sorted(by: { $0.value < $1.value })), id: \.key) { key, value in
                                    Text(value).tag(key)
                                }
                            }

                            Picker("Model", selection: $mode.voiceSettings.model) {
                                ForEach(WhisperModel.allCases, id: \.self) { model in
                                    HStack {
                                        Text(model.displayName)
                                        Spacer()
                                        Text(model.estimatedSize)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(model)
                                }
                            }

                            Toggle("Keep model in memory", isOn: Binding(
                                get: { mode.voiceSettings.keepWarmDuration != nil },
                                set: { enabled in
                                    mode.voiceSettings.keepWarmDuration = enabled ? 300 : nil
                                }
                            ))
                            .help("Faster transcription at the cost of memory usage")
                        }
                    }

                    Divider()

                    // AI Processing
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable AI Processing", isOn: $mode.aiEnabled)
                                .font(.headline)
                                .onChange(of: mode.aiEnabled) { enabled in
                                    if enabled && mode.aiSettings == nil {
                                        mode.aiSettings = AISettings()
                                    }
                                }

                            if mode.aiEnabled, let aiSettingsBinding = Binding($mode.aiSettings) {
                                    Picker("Provider", selection: aiSettingsBinding.provider) {
                                        ForEach(AIProvider.allCases, id: \.self) { provider in
                                            Text(provider.displayName).tag(provider)
                                        }
                                    }
                                    .onChange(of: aiSettingsBinding.provider.wrappedValue) { newProvider in
                                        aiSettingsBinding.model.wrappedValue = newProvider.defaultModel
                                    }

                                    if aiSettingsBinding.provider.wrappedValue == .ollama {
                                        OllamaModelPicker(selection: aiSettingsBinding.model)
                                    } else {
                                        let models = aiSettingsBinding.provider.wrappedValue.availableModels
                                        Picker("Model", selection: aiSettingsBinding.model) {
                                            ForEach(models, id: \.id) { model in
                                                Text(model.name).tag(model.id)
                                            }
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Instructions")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        TextEditor(text: aiSettingsBinding.instructions)
                                            .font(.system(.body, design: .monospaced))
                                            .frame(minHeight: 150)
                                            .border(Color.secondary.opacity(0.3))
                                    }

                                    Toggle("Translate to English", isOn: aiSettingsBinding.translateToEnglish)
                            }
                        }
                    }

                    Divider()

                    // Context Capture
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Context Capture")
                                .font(.headline)

                            Toggle("Capture clipboard", isOn: $mode.contextSettings.captureClipboard)
                            Toggle("Capture selected text", isOn: $mode.contextSettings.captureSelection)
                            Toggle("Capture active app context", isOn: $mode.contextSettings.captureAppContext)

                            if mode.contextSettings.captureSelection || mode.contextSettings.captureAppContext {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Requires Accessibility permissions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    // Output Settings
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Output")
                                .font(.headline)

                            Picker("Output Behavior", selection: $mode.outputBehavior) {
                                Text("Insert at cursor").tag(OutputBehavior.insertAtCursor)
                                Text("Copy to clipboard").tag(OutputBehavior.copyToClipboard)
                                Text("Both").tag(OutputBehavior.both)
                            }
                            .pickerStyle(.radioGroup)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .alert("Validation Error", isPresented: $showingValidationError) {
            Button("OK") { }
        } message: {
            Text(validationMessage)
        }
    }

    private func saveMode() {
        // Validate
        guard !mode.name.isEmpty else {
            validationMessage = "Mode name cannot be empty"
            showingValidationError = true
            return
        }

        if mode.aiEnabled {
            guard mode.aiSettings != nil else {
                validationMessage = "AI settings required when AI processing is enabled"
                showingValidationError = true
                return
            }

            guard !mode.aiSettings!.instructions.isEmpty else {
                validationMessage = "AI instructions cannot be empty"
                showingValidationError = true
                return
            }
        }

        // Save
        if isNew {
            appState.settings.addMode(mode)
        } else {
            appState.settings.updateMode(mode)
        }

        appState.saveSettings()

        print("✓ Mode saved: \(mode.name)")
        self.dismiss()
    }
}

// MARK: - Ollama Model Picker

struct OllamaModelPicker: View {
    @Binding var selection: String
    @ObservedObject private var ollama = OllamaService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(ollama.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(ollama.isRunning ? "Ollama running" : "Ollama not running")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Refresh") {
                    Task { await ollama.checkStatus() }
                }
                .font(.caption)
                .disabled(ollama.isChecking)
            }

            if ollama.isRunning {
                if ollama.availableModels.isEmpty {
                    Text("No models found. Run: ollama pull llama3")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Picker("Model", selection: $selection) {
                        ForEach(ollama.availableModels) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                }
            } else {
                Text("Start Ollama to see available models.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            Task { await ollama.checkStatus() }
        }
    }
}

// MARK: - Preview

#Preview {
    ModeEditorView()
}

#Preview("Edit Mode") {
    ModeEditorView(mode: Mode.email)
}

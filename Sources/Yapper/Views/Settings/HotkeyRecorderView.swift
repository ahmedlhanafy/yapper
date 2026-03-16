import SwiftUI
import Carbon

/// Interactive hotkey recorder for capturing keyboard shortcuts
struct HotkeyRecorderView: View {
    let title: String
    @Binding var hotkey: Hotkey?
    @State private var isRecording = false
    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var currentKeyCode: UInt16?
    @State private var validationError: String?

    var body: some View {
        HStack {
            Text(title)

            Spacer()

            // Display current hotkey
            if !isRecording, let hotkey = hotkey {
                Text(hotkey.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .cornerRadius(4)
            }

            // Recording state
            if isRecording {
                HStack(spacing: 4) {
                    if !currentModifiers.isEmpty || currentKeyCode != nil {
                        Text(formatRecordingKeys())
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("Press keys...")
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            // Record button
            Button(isRecording ? "Stop" : "Record") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .buttonStyle(.bordered)

            // Clear button
            if hotkey != nil && !isRecording {
                Button("Clear") {
                    hotkey = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .overlay(
            RecordingOverlay(
                isRecording: $isRecording,
                onKeyPress: handleKeyPress
            )
        )
        .alert("Invalid Hotkey", isPresented: Binding(
            get: { validationError != nil },
            set: { if !$0 { validationError = nil } }
        )) {
            Button("OK") { validationError = nil }
        } message: {
            if let error = validationError {
                Text(error)
            }
        }
    }

    private func formatRecordingKeys() -> String {
        var parts: [String] = []

        if currentModifiers.contains(.command) {
            parts.append("⌘")
        }
        if currentModifiers.contains(.option) {
            parts.append("⌥")
        }
        if currentModifiers.contains(.shift) {
            parts.append("⇧")
        }
        if currentModifiers.contains(.control) {
            parts.append("⌃")
        }

        if let keyCode = currentKeyCode {
            if let keyChar = KeyCodeMapper.string(for: keyCode) {
                parts.append(keyChar)
            }
        }

        return parts.isEmpty ? "" : parts.joined()
    }

    private func startRecording() {
        isRecording = true
        currentModifiers = []
        currentKeyCode = nil
        validationError = nil
    }

    private func stopRecording() {
        isRecording = false

        // Validate hotkey
        guard !currentModifiers.isEmpty else {
            validationError = "Hotkey must include at least one modifier key (⌘, ⌥, ⇧, or ⌃)"
            return
        }

        guard let keyCode = currentKeyCode else {
            validationError = "No key was pressed"
            return
        }

        // Create hotkey
        var modifiers: [KeyModifier] = []
        if currentModifiers.contains(.command) {
            modifiers.append(.command)
        }
        if currentModifiers.contains(.option) {
            modifiers.append(.option)
        }
        if currentModifiers.contains(.shift) {
            modifiers.append(.shift)
        }
        if currentModifiers.contains(.control) {
            modifiers.append(.control)
        }

        hotkey = Hotkey(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }

    private func handleKeyPress(event: NSEvent) {
        currentModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // Only record non-modifier keys
        let keyCode = event.keyCode
        if !isModifierKey(keyCode) {
            currentKeyCode = keyCode

            // Auto-stop recording when a valid key combination is pressed
            if !currentModifiers.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if isRecording {
                        stopRecording()
                    }
                }
            }
        }
    }

    private func isModifierKey(_ keyCode: UInt16) -> Bool {
        // Modifier key codes
        let modifiers: Set<UInt16> = [
            54, 55,  // Command
            58, 61,  // Option
            56, 60,  // Shift
            59, 62,  // Control
            63       // Fn
        ]
        return modifiers.contains(keyCode)
    }
}

// MARK: - Recording Overlay

/// Invisible overlay that captures keyboard events during recording
struct RecordingOverlay: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyPress: (NSEvent) -> Void

    func makeNSView(context: Context) -> RecordingNSView {
        let view = RecordingNSView()
        view.onKeyPress = onKeyPress
        return view
    }

    func updateNSView(_ nsView: RecordingNSView, context: Context) {
        nsView.isRecording = isRecording
    }
}

class RecordingNSView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }

    var onKeyPress: ((NSEvent) -> Void)?
    private var monitor: Any?

    override var acceptsFirstResponder: Bool { true }

    private func startMonitoring() {
        // Become first responder to receive key events
        window?.makeFirstResponder(self)

        // Also monitor global events as backup
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            self.onKeyPress?(event)
            return nil // Consume the event
        }
    }

    private func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        onKeyPress?(event)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        onKeyPress?(event)
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        HotkeyRecorderView(
            title: "Start/Stop Recording:",
            hotkey: .constant(Hotkey(
                keyCode: 15, // R
                modifiers: [.command, .option]
            ))
        )

        HotkeyRecorderView(
            title: "Cycle Modes:",
            hotkey: .constant(nil)
        )
    }
    .padding()
    .frame(width: 500)
}

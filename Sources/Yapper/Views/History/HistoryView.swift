import SwiftUI
import AVFoundation

struct HistoryView: View {
    @State private var sessions: [Session] = []
    @State private var searchText = ""
    @State private var selectedSessionID: UUID?
    @State private var audioPlayer: AVAudioPlayer?

    private var selectedSession: Session? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transcripts...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.quaternary.opacity(0.5))

                // Sessions list
                List(filteredSessions, id: \.id, selection: $selectedSessionID) { session in
                    SessionRow(session: session)
                        .tag(session.id)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        } detail: {
            if let session = selectedSession {
                SessionDetailView(
                    session: session,
                    onReprocess: { mode in
                        Task {
                            await RecordingCoordinator.shared.reprocess(session: session, withMode: mode)
                        }
                    },
                    onPlay: { playAudio(session) },
                    onDelete: { deleteSession(session) }
                )
                .navigationTitle(formatDate(session.timestamp))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a session to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .onAppear {
            loadSessions()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var filteredSessions: [Session] {
        if searchText.isEmpty {
            return sessions
        }
        return sessions.filter { $0.matches(searchText: searchText) }
    }

    private func loadSessions() {
        sessions = StorageManager.shared.loadHistory()
    }

    private func playAudio(_ session: Session) {
        let url = URL(fileURLWithPath: session.audioFilePath)

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            print("▶️ Playing audio")
        } catch {
            print("⚠️ Failed to play audio: \(error)")
        }
    }

    private func deleteSession(_ session: Session) {
        StorageManager.shared.deleteSession(session.id)
        StorageManager.shared.deleteAudioFile(at: session.audioFilePath)
        sessions.removeAll { $0.id == session.id }
        selectedSessionID = nil
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.mode.name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTime(session.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(session.rawTranscript)
                .font(.body)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: Session
    let onReprocess: (Mode) -> Void
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var showingDebug = false
    @State private var showingReprocessSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(formatDate(session.timestamp))
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(session.mode.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Actions
                    HStack {
                        Button(action: onPlay) {
                            Image(systemName: "play.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("Play audio")

                        Button(action: { showingReprocessSheet = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderless)
                        .help("Reprocess with different mode")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .help("Delete")
                    }
                    .font(.title3)
                }

                Divider()

                // Transcript
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcript")
                        .font(.headline)

                    SelectableText(text: session.rawTranscript)
                        .textSelection(.enabled)
                        .padding()
                        .background(.quaternary)
                        .cornerRadius(8)
                }

                // Processed output (if available)
                if let processed = session.processedOutput {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processed Output")
                            .font(.headline)

                        SelectableText(text: processed)
                            .textSelection(.enabled)
                            .padding()
                            .background(.quaternary)
                            .cornerRadius(8)
                    }
                }

                // Context (if available)
                if let context = session.capturedContext {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Context")
                            .font(.headline)

                        if let app = context.activeApp {
                            HStack {
                                Text("App:")
                                    .foregroundColor(.secondary)
                                Text(app.name)
                            }
                            .font(.caption)
                        }

                        if let selection = context.selection {
                            Text("Selection: \(selection.prefix(100))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let clipboard = context.clipboard {
                            Text("Clipboard: \(clipboard.prefix(100))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.headline)

                    HStack {
                        Text("Duration:")
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f seconds", session.duration))
                    }
                    .font(.caption)

                    if let language = session.language {
                        HStack {
                            Text("Language:")
                                .foregroundColor(.secondary)
                            Text(language)
                        }
                        .font(.caption)
                    }

                    if let processingTime = session.processingTime {
                        HStack {
                            Text("Processing Time:")
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f seconds", processingTime))
                        }
                        .font(.caption)
                    }
                }

                // Debug info
                if showingDebug {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Info")
                            .font(.headline)

                        if let prompt = session.aiPrompt {
                            Text("Prompt:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(prompt)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .padding()
                                .background(.quaternary)
                                .cornerRadius(8)
                        }

                        if let provider = session.aiProvider, let model = session.aiModel {
                            Text("Model: \(provider) / \(model)")
                                .font(.caption)
                        }

                        Text("Audio Path: \(session.audioFilePath)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button(showingDebug ? "Hide Debug Info" : "Show Debug Info") {
                    showingDebug.toggle()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding()
        }
        .sheet(isPresented: $showingReprocessSheet) {
            ReprocessSheet(session: session, onReprocess: onReprocess)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reprocess Sheet

struct ReprocessSheet: View {
    let session: Session
    let onReprocess: (Mode) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedMode: Mode?

    var body: some View {
        VStack(spacing: 20) {
            Text("Reprocess with Mode")
                .font(.title2)
                .fontWeight(.bold)

            List(AppState.shared.settings.modes, id: \.id, selection: $selectedMode) { mode in
                VStack(alignment: .leading) {
                    Text(mode.name)
                        .font(.headline)
                    Text(mode.aiEnabled ? "AI Enabled" : "Voice Only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 300)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Reprocess") {
                    if let mode = selectedMode {
                        onReprocess(mode)
                        dismiss()
                    }
                }
                .disabled(selectedMode == nil)
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Selectable Text

struct SelectableText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(wrappingLabelWithString: text)
        textField.isEditable = false
        textField.isSelectable = true
        textField.isBordered = false
        textField.backgroundColor = .clear
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .frame(width: 900, height: 600)
}

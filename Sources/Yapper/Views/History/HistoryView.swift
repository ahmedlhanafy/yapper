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
        HStack(spacing: 0) {
            // List
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .cornerRadius(6)
                .padding(10)

                Divider()

                if filteredSessions.isEmpty {
                    Spacer()
                    Text(sessions.isEmpty ? "No recordings yet" : "No matches")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredSessions) { session in
                                SessionRow(
                                    session: session,
                                    isSelected: selectedSessionID == session.id
                                )
                                .onTapGesture { selectedSessionID = session.id }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(width: 260)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Detail
            if let session = selectedSession {
                SessionDetailView(
                    session: session,
                    onPlay: { playAudio(session) },
                    onReprocess: { mode in
                        Task { await RecordingCoordinator.shared.reprocess(session: session, withMode: mode) }
                    },
                    onDelete: { deleteSession(session) }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Select a recording")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { loadSessions() }
    }

    private var filteredSessions: [Session] {
        if searchText.isEmpty { return sessions }
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
        } catch {
            print("Failed to play audio: \(error)")
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
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(session.mode.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)

                Spacer()

                Text(timeAgo(session.timestamp))
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.6))
            }

            Text(session.rawTranscript)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 6)
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: Session
    let onPlay: () -> Void
    let onReprocess: (Mode) -> Void
    let onDelete: () -> Void

    @State private var showingDebug = false
    @State private var showingReprocessSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(session.timestamp))
                            .font(.system(size: 15, weight: .semibold))
                        Text(session.mode.name)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: onPlay) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Play audio")

                        Button(action: { showingReprocessSheet = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .help("Reprocess")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .help("Delete")
                    }
                }

                Divider()

                // Transcript
                VStack(alignment: .leading, spacing: 6) {
                    Text("Transcript")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(session.rawTranscript)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                        .cornerRadius(6)
                }

                // Processed output
                if let processed = session.processedOutput {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Processed")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(processed)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                            .cornerRadius(6)
                    }
                }

                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text("Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow {
                            Text("Duration")
                                .foregroundColor(.secondary.opacity(0.6))
                            Text(String(format: "%.1fs", session.duration))
                        }
                        if let language = session.language {
                            GridRow {
                                Text("Language")
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text(language)
                            }
                        }
                        if let time = session.processingTime, time > 0 {
                            GridRow {
                                Text("Processing")
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text(String(format: "%.2fs", time))
                            }
                        }
                        if let provider = session.aiProvider {
                            GridRow {
                                Text("Provider")
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("\(provider)\(session.aiModel.map { " / \($0)" } ?? "")")
                            }
                        }
                    }
                    .font(.system(size: 12))
                }

                // Context
                if let context = session.capturedContext,
                   (context.activeApp != nil || context.selection != nil || context.clipboard != nil) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Context")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        if let app = context.activeApp {
                            Text(app.name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 16) {
            Text("Reprocess with Mode")
                .font(.headline)

            List(AppState.shared.settings.modes, id: \.id, selection: $selectedMode) { mode in
                VStack(alignment: .leading) {
                    Text(mode.name)
                        .font(.system(size: 13, weight: .medium))
                    Text(mode.aiEnabled ? "AI Enabled" : "Voice Only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 250)

            HStack {
                Button("Cancel") { dismiss() }
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
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
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

#Preview {
    HistoryView()
        .frame(width: 700, height: 500)
}

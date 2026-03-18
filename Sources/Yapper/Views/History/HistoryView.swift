import SwiftUI
import AVFoundation

// MARK: - Audio Player

class AudioPlayerState: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(_ path: String) {
        stop()
        let url = URL(fileURLWithPath: path)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        player = p
        duration = p.duration
        currentTime = 0
    }

    func playPause() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            p.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }

    func restart() {
        player?.currentTime = 0
        currentTime = 0
        if !isPlaying { playPause() }
    }

    func stop() {
        player?.stop()
        player = nil
        timer?.invalidate()
        timer = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.timer?.invalidate()
        }
    }
}

struct HistoryView: View {
    @State private var sessions: [Session] = []
    @State private var searchText = ""
    @State private var selectedSessionID: UUID?
    @StateObject private var audioPlayer = AudioPlayerState()

    private var selectedSession: Session? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Session list
            VStack(spacing: 0) {
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
                    VStack(spacing: 6) {
                        Image(systemName: sessions.isEmpty ? "waveform" : "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(sessions.isEmpty ? "No recordings yet" : "No matches")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
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
                    audioPlayer: audioPlayer,
                    onReprocess: { mode in
                        Task { await RecordingCoordinator.shared.reprocess(session: session, withMode: mode) }
                    },
                    onDelete: { deleteSession(session) }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.3))
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

    private func deleteSession(_ session: Session) {
        audioPlayer.stop()
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
    @ObservedObject var audioPlayer: AudioPlayerState
    let onReprocess: (Mode) -> Void
    let onDelete: () -> Void

    @State private var showingReprocessSheet = false
    @State private var copiedField: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(session.timestamp))
                            .font(.system(size: 15, weight: .semibold))
                        HStack(spacing: 6) {
                            Text(session.mode.name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            if let language = session.language {
                                Text("·")
                                    .foregroundColor(.secondary.opacity(0.4))
                                Text(language.uppercased())
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(String(format: "%.1fs", session.duration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button(action: { showingReprocessSheet = true }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.borderless)
                        .help("Reprocess")

                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .frame(width: 26, height: 26)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .help("Delete")
                    }
                }

                // Audio player
                AudioTransportView(player: audioPlayer)

                // Transcript
                CopyableTextBlock(
                    label: "Transcript",
                    text: session.rawTranscript,
                    isCopied: copiedField == "transcript",
                    onCopy: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(session.rawTranscript, forType: .string)
                        copiedField = "transcript"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if copiedField == "transcript" { copiedField = nil }
                        }
                    }
                )

                // Processed output
                if let processed = session.processedOutput, !processed.isEmpty {
                    CopyableTextBlock(
                        label: "Processed",
                        text: processed,
                        isCopied: copiedField == "processed",
                        onCopy: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(processed, forType: .string)
                            copiedField = "processed"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedField == "processed" { copiedField = nil }
                            }
                        }
                    )
                }

                // Provider info
                if let provider = session.aiProvider {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("\(provider)\(session.aiModel.map { " / \($0)" } ?? "")")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        if let time = session.processingTime, time > 0 {
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.4))
                            Text(String(format: "%.2fs", time))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Context
                if let context = session.capturedContext {
                    if let app = context.activeApp {
                        HStack(spacing: 6) {
                            Image(systemName: "app.badge")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(app.name)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            if let url = app.url {
                                Text(url)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { audioPlayer.load(session.audioFilePath) }
        .onChange(of: session.id) { _ in audioPlayer.load(session.audioFilePath) }
        .onDisappear { audioPlayer.stop() }
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

// MARK: - Copyable Text Block

struct CopyableTextBlock: View {
    let label: String
    let text: String
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onCopy) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(isCopied ? "Copied" : "Copy")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(isCopied ? .green : .secondary)
                }
                .buttonStyle(.borderless)
            }

            Text(text)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Audio Transport

struct AudioTransportView: View {
    @ObservedObject var player: AudioPlayerState

    var body: some View {
        HStack(spacing: 12) {
            // Restart
            Button(action: { player.restart() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 11))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .help("Restart")

            // Play/Pause
            Button(action: { player.playPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .help(player.isPlaying ? "Pause" : "Play")

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        .frame(height: 4)

                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.6))
                        .frame(
                            width: player.duration > 0
                                ? geo.size.width * CGFloat(player.currentTime / player.duration)
                                : 0,
                            height: 4
                        )
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 28)

            // Time
            Text(formatTime(player.currentTime) + " / " + formatTime(player.duration))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.1))
        .cornerRadius(8)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
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

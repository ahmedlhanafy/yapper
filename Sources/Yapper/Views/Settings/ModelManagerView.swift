import SwiftUI

/// UI for downloading and managing Whisper models
struct ModelManagerView: View {
    @State private var modelStates: [WhisperModel: ModelState] = [:]
    @State private var downloadProgress: [WhisperModel: Double] = [:]

    enum ModelState: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Whisper Models")
                .font(.headline)

            Text("Download voice recognition models. Larger models are more accurate but slower.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            ForEach(WhisperModel.allCases, id: \.self) { model in
                modelRow(for: model)
            }

            Spacer()

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Models are stored in ~/Library/Application Support/Yapper/Models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            checkModelStates()
        }
    }

    @ViewBuilder
    private func modelRow(for model: WhisperModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)

                        if state(for: model) == .downloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Text(model.estimatedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(modelDescription(for: model))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                actionButton(for: model)
            }

            if state(for: model) == .downloading,
               let progress = downloadProgress[model] {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                Text("\(Int(progress * 100))% downloaded")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if case .failed(let error) = state(for: model) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func actionButton(for model: WhisperModel) -> some View {
        switch state(for: model) {
        case .notDownloaded:
            Button("Download") {
                downloadModel(model)
            }

        case .downloading:
            Button("Cancel") {
                // TODO: Cancel download
            }
            .disabled(true)

        case .downloaded:
            Menu {
                Button("Re-download") {
                    deleteAndDownload(model)
                }

                Button("Delete", role: .destructive) {
                    deleteModel(model)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .frame(width: 100)

        case .failed:
            Button("Retry") {
                downloadModel(model)
            }
        }
    }

    private func state(for model: WhisperModel) -> ModelState {
        modelStates[model] ?? .notDownloaded
    }

    private func modelDescription(for model: WhisperModel) -> String {
        switch model {
        case .tiny:
            return "Very fast, basic accuracy • Good for quick notes"
        case .base:
            return "Fast, good accuracy • Recommended for most users"
        case .small:
            return "Slower, better accuracy • For important recordings"
        case .medium:
            return "Slow, excellent accuracy • For meetings and transcription"
        case .large:
            return "Very slow, best accuracy • For critical transcriptions"
        }
    }

    private func checkModelStates() {
        for model in WhisperModel.allCases {
            let isDownloaded = WhisperService.shared.isModelDownloaded(model)
            modelStates[model] = isDownloaded ? .downloaded : .notDownloaded
        }
    }

    private func downloadModel(_ model: WhisperModel) {
        modelStates[model] = .downloading
        downloadProgress[model] = 0.0

        Task {
            do {
                try await WhisperService.shared.downloadModel(model) { progress in
                    DispatchQueue.main.async {
                        downloadProgress[model] = progress
                    }
                }

                await MainActor.run {
                    modelStates[model] = .downloaded
                    downloadProgress[model] = nil
                }

                print("✓ Model downloaded: \(model.displayName)")
            } catch {
                await MainActor.run {
                    modelStates[model] = .failed(error.localizedDescription)
                    downloadProgress[model] = nil
                }

                print("❌ Model download failed: \(error)")
            }
        }
    }

    private func deleteModel(_ model: WhisperModel) {
        do {
            try WhisperService.shared.deleteModel(model)
            modelStates[model] = .notDownloaded
            print("✓ Model deleted: \(model.displayName)")
        } catch {
            modelStates[model] = .failed("Delete failed")
            print("❌ Failed to delete model: \(error)")
        }
    }

    private func deleteAndDownload(_ model: WhisperModel) {
        deleteModel(model)
        downloadModel(model)
    }
}

// MARK: - Preview

#Preview {
    ModelManagerView()
        .frame(width: 600, height: 500)
}

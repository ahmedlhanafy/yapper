import Foundation
import AppKit
import Combine

/// Coordinates the entire dictation workflow: Record → Transcribe → Process → Insert
class RecordingCoordinator: ObservableObject {
    static let shared = RecordingCoordinator()

    @Published var state: ProcessingState = .idle
    @Published var currentSession: Session?

    private var recordingStartTime: Date?
    private var audioURL: URL?
    private var startContext: CapturedContext?  // Context captured at recording start
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Recording Control

    func toggleRecording() {
        if AppState.shared.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func startRecording() {
        guard state == .idle else {
            print("⚠️ Cannot start recording - already processing")
            UserNotificationService.shared.showToast("Already processing...")
            return
        }

        do {
            recordingStartTime = Date()
            state = .recording

            // Capture context at start (for clipboard and selection)
            let contextSettings = AppState.shared.currentMode.contextSettings

            if contextSettings.captureClipboard || contextSettings.captureSelection {
                startContext = ContextCapture.shared.captureContext(for: contextSettings)
                print("📋 Captured start context")
            } else {
                startContext = nil
            }

            // Start audio recording
            let url = try AudioEngine.shared.startRecording()
            audioURL = url

            AppState.shared.isRecording = true

            print("🎙️ Recording started")
            print("  Mode: \(AppState.shared.currentMode.name)")

            // Show visual feedback - recording window
            MiniRecordingWindowController.shared.show()

        } catch {
            print("❌ Failed to start recording: \(error)")
            state = .error(error.localizedDescription)
            MiniRecordingWindowController.shared.show()

            // Hide window after showing error
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                MiniRecordingWindowController.shared.hide()
            }
        }
    }

    func stopRecording() {
        guard AppState.shared.isRecording else { return }

        // Stop audio
        guard let audioURL = AudioEngine.shared.stopRecording() else {
            print("⚠️ No recording URL")
            state = .idle
            AppState.shared.isRecording = false
            return
        }

        self.audioURL = audioURL
        AppState.shared.isRecording = false

        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())
        print("🎙️ Recording stopped (\(String(format: "%.1f", duration))s)")

        // Recording window will stay visible during processing
        // Process recording
        Task {
            await processRecording(audioURL: audioURL, duration: duration)
        }
    }

    func cancelRecording() {
        print("🚫 Recording cancelled")

        // Stop audio without processing
        _ = AudioEngine.shared.stopRecording()
        AppState.shared.isRecording = false
        state = .idle
        currentSession = nil
        audioURL = nil
        recordingStartTime = nil

        // Hide recording window
        MiniRecordingWindowController.shared.hide()
    }

    // MARK: - Processing Pipeline

    private func processRecording(audioURL: URL, duration: TimeInterval) async {
        let mode = AppState.shared.currentMode
        let contextSettings = mode.contextSettings

        do {
            // Step 1: Transcribe
            await MainActor.run {
                state = .transcribing
            }

            let transcription = try await WhisperService.shared.transcribe(
                audioURL: audioURL,
                model: mode.voiceSettings.model,
                language: mode.voiceSettings.language
            )

            print("✓ Transcription: \(transcription.text)")

            // Check for blank audio
            let trimmed = transcription.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed == "[BLANK_AUDIO]" || trimmed == "(blank audio)" || trimmed == "[silence]" {
                print("⏭️ Blank audio detected, skipping")
                await MainActor.run {
                    state = .idle
                    UserNotificationService.shared.showToast("No speech detected")
                }
                return
            }

            // Step 2: Merge start context with app context (captured now)
            var capturedContext: CapturedContext? = startContext ?? CapturedContext()

            if contextSettings.captureAppContext {
                // Capture current app context
                let appContext = ContextCapture.shared.captureContext(for: contextSettings)
                capturedContext?.activeApp = appContext.activeApp
            }

            // Clear start context after use
            startContext = nil

            // Step 3: AI Processing (if enabled)
            var processedOutput: String?
            var aiPrompt: String?
            var aiProvider: String?
            var aiModel: String?
            var processingTime: TimeInterval = 0

            if mode.aiEnabled {
                await MainActor.run {
                    state = .processing
                }

                let result = try await AIProcessor.shared.process(
                    transcript: transcription.text,
                    mode: mode,
                    context: capturedContext
                )

                processedOutput = result.output
                aiPrompt = result.prompt
                aiProvider = result.provider
                aiModel = result.model
                processingTime = result.processingTime

                print("✓ AI processed: \(processedOutput?.prefix(50) ?? "")...")
            }

            // Step 4: Create session record
            let session = Session(
                timestamp: recordingStartTime ?? Date(),
                audioFilePath: audioURL.path,
                duration: duration,
                rawTranscript: transcription.text,
                language: transcription.language,
                processedOutput: processedOutput,
                mode: mode,
                processingTime: processingTime,
                capturedContext: capturedContext,
                aiPrompt: aiPrompt,
                aiProvider: aiProvider,
                aiModel: aiModel
            )

            // Save to history
            StorageManager.shared.saveSession(session)

            // Step 5: Insert/Copy output
            await MainActor.run {
                state = .inserting
                currentSession = session
            }

            try await insertOutput(session.finalOutput, behavior: mode.outputBehavior)

            // Done!
            await MainActor.run {
                state = .done

                // Show success notification
                let wordCount = session.finalOutput.split(separator: " ").count
                UserNotificationService.shared.showToast(
                    ErrorMessages.transcriptionComplete(wordCount)
                )
            }

            // Reset after delay
            try await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                state = .idle
                currentSession = nil
                // Window already hidden before insertion
            }

        } catch {
            print("❌ Processing failed: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")

            // Provide user-friendly error message based on error type
            let userMessage: String
            if let ollamaError = error as? OllamaError {
                userMessage = ollamaError.errorDescription ?? ErrorMessages.aiProcessingFailed(error)
            } else if let whisperError = error as? WhisperError {
                userMessage = ErrorMessages.transcriptionFailed(error)
            } else if let insertError = error as? TextInsertionError {
                userMessage = ErrorMessages.textInsertionFailed(error)
            } else if error.localizedDescription.contains("transcription") ||
                      error.localizedDescription.lowercased().contains("model") {
                userMessage = ErrorMessages.transcriptionFailed(error)
            } else if error.localizedDescription.contains("API") {
                userMessage = ErrorMessages.aiProcessingFailed(error)
            } else if error.localizedDescription.contains("insert") ||
                      error.localizedDescription.contains("accessibility") {
                userMessage = ErrorMessages.textInsertionFailed(error)
            } else {
                userMessage = ErrorMessages.unexpectedError(error)
            }

            await MainActor.run {
                state = .error(userMessage)

                // Show error notification
                UserNotificationService.shared.showError(
                    title: "Recording Failed",
                    message: userMessage
                )
            }

            // Reset after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                state = .idle

                // Hide recording window
                MiniRecordingWindowController.shared.hide()
            }
        }
    }

    // MARK: - Output

    private func insertOutput(_ text: String, behavior: OutputBehavior) async throws {
        // IMPORTANT: Hide window and restore focus to original app BEFORE inserting
        // This ensures the paste goes to the right application
        await MainActor.run {
            MiniRecordingWindowController.shared.hide()
            MiniRecordingWindowController.shared.restorePreviousApp()
        }

        // Wait for focus to settle
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms

        switch behavior {
        case .insertAtCursor:
            try await TextInserter.shared.insertAtCursor(text)

        case .copyToClipboard:
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                print("✓ Copied to clipboard")
            }

        case .both:
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            try await TextInserter.shared.insertAtCursor(text)
        }
    }

    // MARK: - Reprocessing

    func reprocess(session: Session, withMode newMode: Mode) async {
        print("🔄 Reprocessing session with mode: \(newMode.name)")

        do {
            await MainActor.run {
                state = .processing
            }

            let result = try await AIProcessor.shared.process(
                transcript: session.rawTranscript,
                mode: newMode,
                context: session.capturedContext
            )

            let newSession = Session(
                timestamp: Date(),
                audioFilePath: session.audioFilePath,
                duration: session.duration,
                rawTranscript: session.rawTranscript,
                language: session.language,
                processedOutput: result.output,
                mode: newMode,
                processingTime: result.processingTime,
                capturedContext: session.capturedContext,
                aiPrompt: result.prompt,
                aiProvider: result.provider,
                aiModel: result.model
            )

            StorageManager.shared.saveSession(newSession)

            await MainActor.run {
                currentSession = newSession
                state = .done
            }

            print("✓ Reprocessing complete")

        } catch {
            print("❌ Reprocessing failed: \(error)")
            await MainActor.run {
                state = .error(error.localizedDescription)
            }
        }
    }
}

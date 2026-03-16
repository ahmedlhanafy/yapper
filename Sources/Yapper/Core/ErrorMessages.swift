import Foundation

/// User-friendly error messages for Yapper
struct ErrorMessages {

    // MARK: - Audio Errors

    static func audioPermissionDenied() -> String {
        """
        Microphone access is required for Yapper to work.

        Please go to System Settings > Privacy & Security > Microphone and enable access for Yapper.
        """
    }

    static func audioDeviceNotFound() -> String {
        """
        The selected microphone is not available.

        Please check your audio settings or select a different microphone.
        """
    }

    static func audioRecordingFailed(_ error: Error) -> String {
        """
        Recording failed: \(error.localizedDescription)

        Please check your microphone connection and try again.
        """
    }

    // MARK: - Transcription Errors

    static func transcriptionFailed(_ error: Error) -> String {
        """
        Transcription failed: \(error.localizedDescription)

        This might be due to:
        • Audio quality issues
        • Model not downloaded
        • Insufficient disk space

        Try recording again or check your settings.
        """
    }

    static func modelNotDownloaded(_ model: WhisperModel) -> String {
        """
        The \(model.displayName) model is not downloaded.

        Go to Settings > Advanced > Whisper Models to download it.
        """
    }

    static func modelDownloadFailed(_ model: WhisperModel, _ error: Error) -> String {
        """
        Failed to download \(model.displayName):
        \(error.localizedDescription)

        Please check your internet connection and try again.
        """
    }

    static func audioFileTooShort() -> String {
        """
        Recording is too short to transcribe.

        Please speak for at least 1 second.
        """
    }

    // MARK: - AI Processing Errors

    static func aiProcessingFailed(_ error: Error) -> String {
        """
        AI processing failed: \(error.localizedDescription)

        Possible causes:
        • Invalid or expired API key
        • Network connection issue
        • Service temporarily unavailable

        Check your API key in Settings > API Keys.
        """
    }

    static func apiKeyMissing(_ provider: AIProvider) -> String {
        """
        \(provider.displayName) API key is not configured.

        Please add your API key in Settings > API Keys to use AI processing.
        """
    }

    static func rateLimitExceeded(_ provider: AIProvider) -> String {
        """
        \(provider.displayName) rate limit exceeded.

        Please wait a moment and try again, or check your API usage.
        """
    }

    // MARK: - Context Capture Errors

    static func accessibilityPermissionDenied() -> String {
        """
        Accessibility access is required for this feature.

        Please go to System Settings > Privacy & Security > Accessibility and enable access for Yapper.
        """
    }

    static func clipboardAccessFailed() -> String {
        """
        Unable to access the clipboard.

        This might be a temporary issue. Please try again.
        """
    }

    // MARK: - Text Insertion Errors

    static func textInsertionFailed(_ error: Error) -> String {
        """
        Failed to insert text: \(error.localizedDescription)

        Yapper needs Accessibility permissions to insert text.
        Go to System Settings > Privacy & Security > Accessibility.
        """
    }

    static func noActiveApplication() -> String {
        """
        No active application found.

        Please click in a text field where you want to insert the text.
        """
    }

    // MARK: - Storage Errors

    static func storageFull() -> String {
        """
        Insufficient disk space.

        Please free up some space and try again.
        """
    }

    static func fileNotFound(_ filename: String) -> String {
        """
        File not found: \(filename)

        The file may have been moved or deleted.
        """
    }

    static func exportFailed(_ error: Error) -> String {
        """
        Export failed: \(error.localizedDescription)

        Please check file permissions and available disk space.
        """
    }

    static func importFailed(_ error: Error) -> String {
        """
        Import failed: \(error.localizedDescription)

        Please ensure the file is a valid Yapper backup.
        """
    }

    // MARK: - Hotkey Errors

    static func hotkeyRegistrationFailed() -> String {
        """
        Failed to register global hotkey.

        The key combination might be already in use by another app.
        Please try a different combination.
        """
    }

    static func hotkeyInvalid() -> String {
        """
        Invalid hotkey combination.

        Please use at least one modifier key (⌘, ⌥, ⌃, or ⇧).
        """
    }

    // MARK: - Network Errors

    static func networkUnavailable() -> String {
        """
        No internet connection.

        Some features require an internet connection.
        Please check your network and try again.
        """
    }

    static func requestTimeout() -> String {
        """
        Request timed out.

        The operation took too long. Please try again.
        """
    }

    // MARK: - General Errors

    static func unexpectedError(_ error: Error) -> String {
        """
        An unexpected error occurred:
        \(error.localizedDescription)

        Please try again. If the problem persists, please restart Yapper.
        """
    }

    static func operationCancelled() -> String {
        """
        Operation was cancelled.
        """
    }

    // MARK: - Success Messages

    static func recordingComplete(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "Recording complete: \(minutes)m \(seconds)s"
        } else {
            return "Recording complete: \(seconds)s"
        }
    }

    static func transcriptionComplete(_ wordCount: Int) -> String {
        "Transcribed \(wordCount) word\(wordCount == 1 ? "" : "s")"
    }

    static func textInserted() -> String {
        "Text inserted successfully"
    }

    static func settingsSaved() -> String {
        "Settings saved"
    }

    static func modelDownloadComplete(_ model: WhisperModel) -> String {
        "\(model.displayName) model downloaded successfully"
    }

    // MARK: - Help Messages

    static func gettingStarted() -> String {
        """
        Getting Started with Yapper:

        1. Press your hotkey (⌘⌥Space) to start recording
        2. Speak clearly into your microphone
        3. Press the hotkey again to stop
        4. Your text will be inserted automatically

        Tip: Adjust modes in Settings for different writing styles!
        """
    }

    static func firstTimeSetup() -> String {
        """
        Welcome to Yapper!

        Before you start:
        • Grant Microphone access when prompted
        • Grant Accessibility access for text insertion
        • Download a Whisper model in Settings > Advanced

        Ready to go? Press ⌘⌥Space to start!
        """
    }
}

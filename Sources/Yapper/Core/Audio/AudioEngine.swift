import Foundation
import AVFoundation
import Accelerate

/// Manages audio capture from microphone
class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    @Published var isRecording = false
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var currentLevel: Float = 0.0 // For waveform visualization

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    // Audio format: 16kHz mono for Whisper (most efficient)
    private let sampleRate: Double = 16000
    private let channelCount: UInt32 = 1

    private var levelTimer: Timer?

    private init() {
        setupNotifications()
    }

    // MARK: - Permissions

    enum PermissionStatus {
        case notDetermined
        case denied
        case granted
    }

    func requestPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            permissionStatus = .granted
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionStatus = granted ? .granted : .denied
                }
            }
        case .denied, .restricted:
            permissionStatus = .denied
        @unknown default:
            permissionStatus = .denied
        }
    }

    // MARK: - Recording

    func startRecording(deviceID: String? = nil) throws -> URL {
        guard permissionStatus == .granted else {
            throw AudioError.permissionDenied
        }

        guard !isRecording else {
            throw AudioError.alreadyRecording
        }

        // Create output URL
        let outputURL = generateOutputURL()
        recordingURL = outputURL

        // Setup audio engine
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        self.inputNode = inputNode

        // Select input device if specified
        if let deviceID = deviceID {
            try setInputDevice(deviceID)
        }

        // Get input format (device's native format)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

        // Create desired format for Whisper (16kHz mono float32)
        // Using float32 for better compatibility with AVAudioConverter
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        ) else {
            throw AudioError.formatCreationFailed
        }
        print("🎤 Output format: \(outputFormat.sampleRate)Hz, \(outputFormat.channelCount) channels")

        // Create audio file
        do {
            audioFile = try AVAudioFile(
                forWriting: outputURL,
                settings: outputFormat.settings
            )
        } catch {
            throw AudioError.fileCreationFailed(error)
        }

        // Create converter if formats don't match
        guard let converter = AVAudioConverter(
            from: inputFormat,
            to: outputFormat
        ) else {
            print("❌ Failed to create audio converter")
            print("   Input: \(inputFormat)")
            print("   Output: \(outputFormat)")
            throw AudioError.converterCreationFailed
        }
        print("✅ Audio converter created successfully")

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, converter: converter)
        }
        print("✅ Audio tap installed")

        // Start engine
        do {
            try engine.start()
            isRecording = true
            startLevelMonitoring()
            print("✓ Recording started: \(outputURL.lastPathComponent)")
        } catch {
            throw AudioError.engineStartFailed(error)
        }

        return outputURL
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        // Stop engine
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil

        // Close audio file
        audioFile = nil

        isRecording = false
        stopLevelMonitoring()

        print("✓ Recording stopped")

        let url = recordingURL
        recordingURL = nil
        return url
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        guard let audioFile = audioFile else { return }

        // Convert to target format
        let outputFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (sampleRate / buffer.format.sampleRate)
        )

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            print("⚠️ Failed to create converted buffer")
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("⚠️ Conversion error: \(error)")
            print("   Status: \(status.rawValue)")
            return
        }

        if status == .error {
            print("⚠️ Conversion failed with error status")
            return
        }

        // Apply normalization if enabled
        if AppState.shared.settings.enableNormalization {
            normalizeBuffer(convertedBuffer)
        }

        // Write to file
        do {
            try audioFile.write(from: convertedBuffer)
        } catch {
            print("⚠️ Write error: \(error)")
        }

        // Update level for visualization
        updateAudioLevel(buffer)
    }

    private func normalizeBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // Find peak
        var peak: Float = 0
        vDSP_maxv(channelDataValue, 1, &peak, vDSP_Length(frameLength))

        // Normalize if peak > threshold
        if peak > 0.1 {
            var gain = min(0.9 / peak, 2.0) // Max 2x amplification
            vDSP_vsmul(channelDataValue, 1, &gain, channelDataValue, 1, vDSP_Length(frameLength))
        }
    }

    // MARK: - Level Monitoring

    private func startLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Level is updated in processAudioBuffer
            // This timer just triggers UI updates
        }
    }

    private func stopLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
        currentLevel = 0.0
    }

    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)

        // Calculate RMS level
        var rms: Float = 0
        vDSP_rmsqv(channelDataValue, 1, &rms, vDSP_Length(frameLength))

        // Convert to decibels and normalize to 0-1 range
        let db = 20 * log10(max(rms, 0.00001))
        let normalized = max(0, min(1, (db + 50) / 50)) // -50dB to 0dB → 0 to 1

        DispatchQueue.main.async {
            self.currentLevel = normalized
        }
    }

    // MARK: - Device Management

    func availableInputDevices() -> [(id: String, name: String)] {
        #if os(macOS)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.map { device in
            (id: device.uniqueID, name: device.localizedName)
        }
        #else
        return []
        #endif
    }

    private func setInputDevice(_ deviceID: String) throws {
        #if os(macOS)
        guard let device = AVCaptureDevice(uniqueID: deviceID) else {
            throw AudioError.deviceNotFound
        }

        // This requires additional AudioUnit setup on macOS
        // For MVP, we'll use the default device
        print("ℹ️ Custom device selection: \(device.localizedName)")
        #endif
    }

    // MARK: - Utilities

    private func generateOutputURL() -> URL {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "recording_\(timestamp).wav"

        let storageURL = URL(fileURLWithPath: AppState.shared.settings.storageLocation)
            .appendingPathComponent("Recordings")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)

        return storageURL.appendingPathComponent(filename)
    }

    private func setupNotifications() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleInterruption(notification: Notification) {
        guard isRecording else { return }

        // Stop recording on interruption
        _ = stopRecording()
        print("⚠️ Recording interrupted")
    }

    // MARK: - Cleanup

    func stop() {
        if isRecording {
            _ = stopRecording()
        }
    }
}

// MARK: - Errors

enum AudioError: LocalizedError {
    case permissionDenied
    case alreadyRecording
    case formatCreationFailed
    case fileCreationFailed(Error)
    case converterCreationFailed
    case engineStartFailed(Error)
    case deviceNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied. Please grant access in System Settings."
        case .alreadyRecording:
            return "Already recording."
        case .formatCreationFailed:
            return "Failed to create audio format."
        case .fileCreationFailed(let error):
            return "Failed to create audio file: \(error.localizedDescription)"
        case .converterCreationFailed:
            return "Failed to create audio converter."
        case .engineStartFailed(let error):
            return "Failed to start audio engine: \(error.localizedDescription)"
        case .deviceNotFound:
            return "Audio input device not found."
        }
    }
}

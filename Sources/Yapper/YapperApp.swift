import SwiftUI
import AppKit
import ApplicationServices
import Combine

@main
struct YapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // Menubar only app - hide the window
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var menuBarController: MenuBarController?
    private var recordingObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 APP STARTING - applicationDidFinishLaunching called")
        print("🚀 Main thread: \(Thread.isMainThread)")

        // Set app icon (needed when running outside .app bundle)
        NSApp.applicationIconImage = Self.loadAppIcon()

        // Set dock visibility from settings
        if AppState.shared.settings.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        // Apply saved appearance setting
        AppearanceManager.shared.applyAppearance()

        // Check accessibility permissions first
        checkAccessibilityPermissions()

        // Delay setup to avoid CA commit warnings
        DispatchQueue.main.async { [weak self] in
            print("🚀 Inside DispatchQueue.main.async")

            // Hide the main window (SwiftUI creates one by default)
            print("🚀 Windows count: \(NSApp.windows.count)")
            NSApp.windows.forEach { window in
                print("🚀 Window: \(window.title), isEmpty: \(window.contentView?.subviews.isEmpty ?? true)")
                if window.title == "Yapper" || window.contentView?.subviews.isEmpty == true {
                    window.close()
                    print("🚀 Closed window: \(window.title)")
                }
            }

            // Setup menubar
            print("🚀 About to setup menubar...")
            self?.setupMenuBar()

            // Verify menubar was created
            if self?.statusItem != nil {
                print("✅ Menubar icon created successfully")
                print("✅ StatusItem button: \(String(describing: self?.statusItem?.button))")
                print("✅ StatusItem length: \(self?.statusItem?.length ?? 0)")
            } else {
                print("❌ Failed to create menubar icon")
            }

            // Setup global hotkeys
            print("🚀 Setting up hotkeys...")
            HotkeyManager.shared.registerDefaultHotkeys()

            // Initialize audio engine
            print("🚀 Requesting audio permissions...")
            AudioEngine.shared.requestPermissions()

            // Observe recording state to update menubar icon
            self?.setupRecordingObserver()

            // Don't show window on startup - it will appear when recording starts
            // if AppState.shared.settings.showMiniWindow {
            //     print("🚀 Showing mini window...")
            //     MiniRecordingWindowController.shared.show()
            // }

            // Auto-download default Whisper model if not present
            let defaultModel = AppState.shared.currentMode.voiceSettings.model
            if !WhisperService.shared.isModelDownloaded(defaultModel) {
                print("🚀 Default model not found, downloading \(defaultModel.rawValue)...")
                Task {
                    do {
                        try await WhisperService.shared.downloadModel(defaultModel) { _ in }
                        print("✅ Default model downloaded")
                    } catch {
                        print("⚠️ Failed to download default model: \(error)")
                    }
                }
            }

            print("✅✅✅ Yapper launched successfully ✅✅✅")
            print("✅ Press Option+Space to record")
            print("✅ Look for the waveform icon in your menubar (top-right corner)")

            // Keep checking if we're alive
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                print("💓 Yapper is still running...")
            }
        }
    }

    private func setupRecordingObserver() {
        // Observe AppState.isRecording to update menubar icon
        recordingObserver = AppState.shared.$isRecording.sink { [weak self] isRecording in
            DispatchQueue.main.async {
                self?.updateMenuBarIcon(isRecording: isRecording)
            }
        }
    }

    private func updateMenuBarIcon(isRecording: Bool) {
        guard let button = statusItem?.button else { return }

        if isRecording {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
        } else {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Yapper")
        }
        button.image?.isTemplate = true
    }

    static func loadAppIcon() -> NSImage? {
        // Try NSImage(named:) first (works in .app bundle)
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        // Fallback: load from resource bundle PNG (debug builds)
        let bundleName = "Yapper_Yapper.bundle"
        let iconPath = "Assets.xcassets/AppIcon.appiconset/icon_512x512.png"
        if let execURL = Bundle.main.executableURL {
            let bundleURL = execURL.deletingLastPathComponent().appendingPathComponent(bundleName).appendingPathComponent(iconPath)
            if let image = NSImage(contentsOf: bundleURL) {
                return image
            }
        }
        return nil
    }

    private func checkAccessibilityPermissions() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("⚠️ Accessibility permissions NOT granted - requesting...")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("⚠️ Please grant accessibility permissions in System Settings > Privacy & Security > Accessibility")
            print("⚠️ Yapper needs these permissions to:")
            print("   - Register global hotkeys (Option+Space)")
            print("   - Insert transcribed text into applications")
        } else {
            print("✅ Accessibility permissions granted")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup - IMPORTANT: Unload Whisper model first to free Metal resources
        // This prevents the GGML_ASSERT([rsets->data count] == 0) crash
        WhisperService.shared.unloadModel()
        AudioEngine.shared.stop()
        HotkeyManager.shared.unregisterAll()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        print("📍 StatusItem created: \(statusItem != nil)")
        print("📍 StatusItem visible: \(statusItem?.isVisible ?? false)")

        if let button = statusItem?.button {
            print("📍 Button exists: true")

            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Yapper")
            button.image?.isTemplate = true

            button.action = #selector(menuBarButtonClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self

            // Ensure it's visible
            statusItem?.isVisible = true
            button.needsDisplay = true

            print("📍 Button configured with SF Symbol")
            print("📍 Button frame: \(button.frame)")
            print("📍 StatusBar visible property: \(statusItem?.isVisible ?? false)")
        } else {
            print("❌ No button available on statusItem")
        }

        menuBarController = MenuBarController(statusItem: statusItem)
        print("📍 MenuBarController created")
    }

    @objc func menuBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp || !AppState.shared.settings.recordOnMenubarClick {
            // Right click or recordOnMenubarClick disabled - show menu
            menuBarController?.showMenu()
        } else {
            // Left click with recordOnMenubarClick enabled - toggle recording
            RecordingCoordinator.shared.toggleRecording()
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isRecording = false
    @Published var processingState: ProcessingState = .idle
    @Published var settings: Settings = Settings()

    var currentMode: Mode {
        get {
            settings.modes.first { $0.key == settings.defaultModeKey } ?? .voiceToText
        }
        set {
            settings.defaultModeKey = newValue.key
        }
    }

    private init() {
        loadSettings()
    }

    func loadSettings() {
        if let loaded = StorageManager.shared.loadSettings() {
            settings = loaded
        }
    }

    func saveSettings() {
        StorageManager.shared.saveSettings(settings)
    }
}

enum ProcessingState: Equatable {
    case idle
    case recording
    case downloadingModel
    case transcribing
    case processing
    case inserting
    case done
    case error(String)
}

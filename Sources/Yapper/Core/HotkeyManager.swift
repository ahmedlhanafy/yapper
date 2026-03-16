import Foundation
import Carbon

/// Manages global hotkey registration for recording and mode switching
class HotkeyManager {
    static let shared = HotkeyManager()

    private var recordingHotkeyRef: EventHotKeyRef?
    private var cycleModeHotkeyRef: EventHotKeyRef?

    private var eventHandler: EventHandlerRef?

    private init() {}

    // MARK: - Registration

    func registerDefaultHotkeys() {
        let settings = AppState.shared.settings

        if let recordingHotkey = settings.recordingHotkey {
            registerRecordingHotkey(recordingHotkey)
        }

        if let cycleModeHotkey = settings.cycleModeHotkey {
            registerCycleModeHotkey(cycleModeHotkey)
        }
    }

    func registerRecordingHotkey(_ hotkey: Hotkey) {
        unregisterRecordingHotkey()

        // Convert "RCRD" string to FourCharCode (4-byte integer)
        let signature: OSType = 0x52435244 // "RCRD" in hex
        let hotkeyID = EventHotKeyID(signature: signature, id: 1)
        let modifiers = hotkey.modifiers.reduce(0) { $0 | $1.carbonFlag }

        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            recordingHotkeyRef = hotkeyRef
            setupEventHandler()
            print("✓ Registered recording hotkey: \(hotkey.displayString)")
        } else {
            print("⚠️ Failed to register recording hotkey: \(status)")
        }
    }

    func registerCycleModeHotkey(_ hotkey: Hotkey) {
        unregisterCycleModeHotkey()

        // Convert "CYCL" string to FourCharCode (4-byte integer)
        let signature: OSType = 0x4359434C // "CYCL" in hex
        let hotkeyID = EventHotKeyID(signature: signature, id: 2)
        let modifiers = hotkey.modifiers.reduce(0) { $0 | $1.carbonFlag }

        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            cycleModeHotkeyRef = hotkeyRef
            setupEventHandler()
            print("✓ Registered cycle mode hotkey: \(hotkey.displayString)")
        } else {
            print("⚠️ Failed to register cycle mode hotkey: \(status)")
        }
    }

    private func setupEventHandler() {
        guard eventHandler == nil else { return }

        // Listen for both key pressed AND released events
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyReleased))
        ]

        let callback: EventHandlerUPP = { (_, inEvent, _) -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(
                inEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            // Check if this is a press or release event
            let kind = GetEventKind(inEvent)
            let isPressed = (kind == OSType(kEventHotKeyPressed))

            DispatchQueue.main.async {
                HotkeyManager.shared.handleHotkey(hotkeyID, isPressed: isPressed)
            }

            return noErr
        }

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            2, // Listen to 2 event types (pressed and released)
            &eventTypes,
            nil,
            &eventHandler
        )
    }

    private func handleHotkey(_ hotkeyID: EventHotKeyID, isPressed: Bool) {
        print("🔥 Hotkey \(isPressed ? "pressed" : "released")! Signature: \(hotkeyID.signature) (0x\(String(hotkeyID.signature, radix: 16)))")

        switch hotkeyID.signature {
        case 0x52435244: // "RCRD"
            // Recording hotkey - push to talk behavior
            if isPressed {
                print("🎤 Recording hotkey pressed - START recording")
                SoundManager.shared.playStartSound()
                RecordingCoordinator.shared.startRecording()
            } else {
                print("🎤 Recording hotkey released - STOP recording")
                SoundManager.shared.playStopSound()
                RecordingCoordinator.shared.stopRecording()
            }

        case 0x4359434C: // "CYCL"
            // Cycle mode hotkey - only trigger on press
            if isPressed {
                print("🔄 Cycle mode hotkey triggered")
                cycleModes()
            }

        default:
            print("❓ Unknown hotkey signature: \(hotkeyID.signature) (0x\(String(hotkeyID.signature, radix: 16)))")
            break
        }
    }

    // MARK: - Mode Cycling

    private func cycleModes() {
        let modes = AppState.shared.settings.modes
        guard !modes.isEmpty else { return }

        if let currentIndex = modes.firstIndex(where: { $0.key == AppState.shared.settings.defaultModeKey }) {
            let nextIndex = (currentIndex + 1) % modes.count
            let nextMode = modes[nextIndex]

            AppState.shared.settings.defaultModeKey = nextMode.key
            AppState.shared.currentMode = nextMode
            AppState.shared.saveSettings()

            print("🔄 Switched to mode: \(nextMode.name)")

            // Show notification
            showModeChangeNotification(nextMode.name)
        }
    }

    private func showModeChangeNotification(_ modeName: String) {
        // TODO: Show HUD notification
        print("Mode: \(modeName)")
    }

    // MARK: - Unregistration

    func unregisterRecordingHotkey() {
        if let ref = recordingHotkeyRef {
            UnregisterEventHotKey(ref)
            recordingHotkeyRef = nil
        }
    }

    func unregisterCycleModeHotkey() {
        if let ref = cycleModeHotkeyRef {
            UnregisterEventHotKey(ref)
            cycleModeHotkeyRef = nil
        }
    }

    func unregisterAll() {
        unregisterRecordingHotkey()
        unregisterCycleModeHotkey()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

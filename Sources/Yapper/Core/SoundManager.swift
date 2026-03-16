import Foundation
import AppKit

/// Manages audio feedback sounds for recording actions
class SoundManager {
    static let shared = SoundManager()

    private var startSound: NSSound?
    private var stopSound: NSSound?

    private init() {
        // Use subtle macOS system sounds
        // "Morse" is a soft click, "Pop" is a gentle pop
        startSound = NSSound(named: "Morse")
        stopSound = NSSound(named: "Pop")
    }

    /// Play the "start recording" sound
    func playStartSound() {
        startSound?.stop()
        startSound?.play()
    }

    /// Play the "stop recording" sound
    func playStopSound() {
        stopSound?.stop()
        stopSound?.play()
    }
}

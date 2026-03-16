import AppKit
import UserNotifications

/// Service for showing user notifications
class UserNotificationService {
    static let shared = UserNotificationService()

    private init() {
        // Don't request permissions in init - do it lazily when needed
    }

    /// Request notification permission
    func requestPermission() {
        // Wrap in do-catch to prevent crashes when running from Xcode
        do {
            // Check if bundle identifier is valid before requesting
            guard Bundle.main.bundleIdentifier != nil else {
                print("⚠️ No bundle identifier - skipping notification permissions (normal when running from Xcode)")
                return
            }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error = error {
                    print("❌ Notification permission error: \(error)")
                } else if granted {
                    print("✓ Notification permission granted")
                }
            }
        } catch {
            print("⚠️ Failed to request notification permissions: \(error)")
        }
    }

    /// Show success notification
    func showSuccess(title: String, message: String? = nil) {
        show(title: title, message: message, sound: .default)
    }

    /// Show error notification
    func showError(title: String, message: String) {
        // Use toast instead of UNUserNotificationCenter to avoid crashes in Xcode
        showToast("⚠️ \(title): \(message)")
    }

    /// Show info notification
    func showInfo(title: String, message: String? = nil) {
        show(title: title, message: message, sound: nil)
    }

    /// Show notification
    private func show(title: String, message: String?, sound: UNNotificationSound?) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let message = message {
            content.body = message
        }
        if let sound = sound {
            content.sound = sound
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show notification: \(error)")
            }
        }
    }

    /// Show toast-style notification (inline)
    func showToast(_ message: String) {
        DispatchQueue.main.async {
            // Create a simple floating window for toast
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 60),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = true

            // Apply the app's appearance setting to this window
            window.appearance = NSApp.appearance

            // Create toast view with visual effect for blur
            let visualEffect = NSVisualEffectView(frame: window.contentRect(forFrameRect: window.frame))
            visualEffect.material = .hudWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 12
            visualEffect.layer?.masksToBounds = true

            let label = NSTextField(labelWithString: message)
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = .labelColor
            label.alignment = .center
            label.backgroundColor = .clear
            label.isBordered = false
            label.frame = NSRect(x: 10, y: 15, width: 280, height: 30)
            visualEffect.addSubview(label)

            window.contentView = visualEffect

            // Position in bottom-right corner
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.maxX - window.frame.width - 20
                let y = screenFrame.minY + 20
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }

            window.orderFront(nil)
            window.alphaValue = 0
            window.animator().alphaValue = 1

            // Auto-hide after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                window.animator().alphaValue = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    window.orderOut(nil)
                }
            }
        }
    }
}

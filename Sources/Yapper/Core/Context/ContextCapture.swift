import Foundation
import AppKit

/// Captures context from clipboard, selection, and active app
class ContextCapture {
    static let shared = ContextCapture()

    private init() {}

    // MARK: - Capture

    func captureContext(for settings: ContextSettings) -> CapturedContext {
        var context = CapturedContext()

        if settings.captureClipboard {
            context.clipboard = captureClipboard()
        }

        if settings.captureSelection {
            context.selection = captureSelection()
        }

        if settings.captureAppContext {
            context.activeApp = captureActiveApp()
        }

        return context
    }

    // MARK: - Clipboard

    private func captureClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Get string from clipboard
        guard let string = pasteboard.string(forType: .string) else {
            return nil
        }

        // Limit length
        let maxLength = 10000
        if string.count > maxLength {
            return String(string.prefix(maxLength)) + "..."
        }

        print("📋 Captured clipboard (\(string.count) chars)")
        return string
    }

    // MARK: - Selection

    private func captureSelection() -> String? {
        // NOTE: This requires accessibility permissions
        guard hasAccessibilityPermissions() else {
            print("⚠️ No accessibility permissions for selection capture")
            return nil
        }

        // Get focused element
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let app = focusedApp else {
            return nil
        }

        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard elementResult == .success, let element = focusedElement else {
            return nil
        }

        // Get selected text
        var selectedText: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        if textResult == .success, let text = selectedText as? String, !text.isEmpty {
            print("📝 Captured selection (\(text.count) chars)")
            return text
        }

        return nil
    }

    // MARK: - Active App

    private func captureActiveApp() -> AppContext? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let bundleId = activeApp.bundleIdentifier ?? "unknown"
        let name = activeApp.localizedName ?? "Unknown"

        // Try to get window title if we have accessibility permissions
        var windowTitle: String?
        if hasAccessibilityPermissions() {
            windowTitle = getActiveWindowTitle()
        }

        // Try to get URL if it's a browser
        var url: String?
        if isBrowser(bundleId) {
            url = getBrowserURL(bundleId: bundleId)
        }

        print("🪟 Captured app context: \(name)")
        if let url = url {
            print("  URL: \(url)")
        }

        return AppContext(
            bundleId: bundleId,
            name: name,
            windowTitle: windowTitle,
            url: url
        )
    }

    private func getActiveWindowTitle() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let app = focusedApp else {
            return nil
        }

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success, let window = focusedWindow else {
            return nil
        }

        var title: AnyObject?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &title
        )

        if titleResult == .success, let titleString = title as? String {
            return titleString
        }

        return nil
    }

    // MARK: - Browser URL Extraction

    private func isBrowser(_ bundleId: String) -> Bool {
        let browsers = [
            "com.apple.Safari",
            "com.google.Chrome",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "com.vivaldi.Vivaldi"
        ]
        return browsers.contains(bundleId)
    }

    private func getBrowserURL(bundleId: String) -> String? {
        // Use AppleScript to get URL from browser
        var script = ""

        switch bundleId {
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of front document
                end if
            end tell
            """

        case "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser", "com.vivaldi.Vivaldi":
            let appName: String
            switch bundleId {
            case "com.google.Chrome": appName = "Google Chrome"
            case "com.microsoft.edgemac": appName = "Microsoft Edge"
            case "com.brave.Browser": appName = "Brave Browser"
            case "com.vivaldi.Vivaldi": appName = "Vivaldi"
            default: return nil
            }

            script = """
            tell application "\(appName)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """

        default:
            return nil
        }

        guard let appleScript = NSAppleScript(source: script) else {
            return nil
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if let error = error {
            print("⚠️ AppleScript error: \(error)")
            return nil
        }

        return result.stringValue
    }

    // MARK: - Permissions

    func hasAccessibilityPermissions() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

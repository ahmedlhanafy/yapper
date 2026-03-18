import Foundation
import AppKit
import Carbon

/// Inserts text at cursor position using accessibility APIs
class TextInserter {
    static let shared = TextInserter()

    private init() {}

    func insertAtCursor(_ text: String) async throws {
        // Check permissions
        guard ContextCapture.shared.hasAccessibilityPermissions() else {
            throw TextInsertionError.noAccessibilityPermissions
        }

        print("⌨️ Inserting text at cursor...")

        // Save current clipboard contents (all types)
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        let originalClipboard = pasteboard.string(forType: .string)

        // Copy text to clipboard
        await MainActor.run {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        // Wait for clipboard to settle
        try await Task.sleep(nanoseconds: 80_000_000) // 80ms

        // Simulate Cmd+V
        try await simulatePaste()

        // Wait longer for the target app to read the clipboard
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Restore original clipboard
        await MainActor.run {
            // Only restore if no one else changed the clipboard since our paste
            if pasteboard.changeCount == originalChangeCount + 1 {
                pasteboard.clearContents()
                if let original = originalClipboard {
                    pasteboard.setString(original, forType: .string)
                }
            }
        }

        print("✓ Text inserted")
    }

    private func simulatePaste() async throws {
        // Method 1: CGEvent (most reliable for paste)
        let source = CGEventSource(stateID: .combinedSessionState)

        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        cmdDown?.flags = .maskCommand

        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        vDown?.flags = .maskCommand

        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        vUp?.flags = .maskCommand

        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        // Post events
        cmdDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        vDown?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000)

        vUp?.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000)

        cmdUp?.post(tap: .cghidEventTap)
    }

    // Alternative: Direct AX insertion (less reliable but doesn't use clipboard)
    func insertDirectly(_ text: String) throws {
        guard ContextCapture.shared.hasAccessibilityPermissions() else {
            throw TextInsertionError.noAccessibilityPermissions
        }

        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let app = focusedApp else {
            throw TextInsertionError.noFocusedElement
        }

        // Get focused element
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard elementResult == .success, let element = focusedElement else {
            throw TextInsertionError.noFocusedElement
        }

        // Try to get current value
        var currentValue: AnyObject?
        let valueResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            &currentValue
        )

        // Get current selection range
        var selectionRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextRangeAttribute as CFString,
            &selectionRange
        )

        var insertPosition = 0
        if rangeResult == .success,
           let range = selectionRange as! AXValue? {
            var cfRange = CFRange()
            AXValueGetValue(range, .cfRange, &cfRange)
            insertPosition = cfRange.location
        }

        // Build new value
        var newValue = ""
        if valueResult == .success, let value = currentValue as? String {
            // Insert at cursor position
            let startIndex = value.index(value.startIndex, offsetBy: insertPosition)
            newValue = value.prefix(upTo: startIndex) + text + value.suffix(from: startIndex)
        } else {
            // No existing value - just use text
            newValue = text
        }

        // Set new value
        let setResult = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXValueAttribute as CFString,
            newValue as CFTypeRef
        )

        if setResult != .success {
            throw TextInsertionError.insertionFailed
        }

        print("✓ Text inserted directly via AX")
    }
}

// MARK: - Errors

enum TextInsertionError: LocalizedError {
    case noAccessibilityPermissions
    case noFocusedElement
    case insertionFailed

    var errorDescription: String? {
        switch self {
        case .noAccessibilityPermissions:
            return "Accessibility permissions required. Please grant access in System Settings > Privacy & Security > Accessibility."
        case .noFocusedElement:
            return "No focused text field found."
        case .insertionFailed:
            return "Failed to insert text."
        }
    }
}

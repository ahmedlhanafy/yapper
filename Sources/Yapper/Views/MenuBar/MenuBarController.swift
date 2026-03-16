import AppKit
import SwiftUI

/// Manages the menubar icon and menu
class MenuBarController {
    private weak var statusItem: NSStatusItem?
    private var menu: NSMenu?

    init(statusItem: NSStatusItem?) {
        self.statusItem = statusItem
        buildMenu()
    }

    func showMenu() {
        statusItem?.button?.performClick(nil)
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Recording status
        let statusItem = NSMenuItem(
            title: "Status: Idle",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Start/Stop Recording
        let recordItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = [.command, .shift]
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // Modes submenu
        let modesItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modesSubmenu = NSMenu()

        for mode in AppState.shared.settings.modes {
            let item = NSMenuItem(
                title: mode.name,
                action: #selector(selectMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            item.state = mode.key == AppState.shared.settings.defaultModeKey ? .on : .off
            modesSubmenu.addItem(item)
        }

        modesItem.submenu = modesSubmenu
        menu.addItem(modesItem)

        menu.addItem(NSMenuItem.separator())

        // History
        let historyItem = NSMenuItem(
            title: "History...",
            action: #selector(openHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self
        menu.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Yapper",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        self.menu = menu
        if let item = self.statusItem {
            item.menu = menu
        }

        // Update menu dynamically
        setupMenuUpdates()
    }

    private func setupMenuUpdates() {
        // Update status text based on app state
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateMenuStatus()
        }
    }

    private func updateMenuStatus() {
        guard let menu = menu,
              let statusItem = menu.item(at: 0) else { return }

        let state = AppState.shared.processingState
        let statusText: String

        switch state {
        case .idle:
            statusText = "Status: Idle"
        case .recording:
            statusText = "Status: Recording..."
        case .transcribing:
            statusText = "Status: Transcribing..."
        case .processing:
            statusText = "Status: Processing..."
        case .inserting:
            statusText = "Status: Inserting..."
        case .done:
            statusText = "Status: Done ✓"
        case .error:
            statusText = "Status: Error"
        }

        statusItem.title = statusText

        // Update recording menu item
        if let recordItem = menu.item(at: 2) {
            recordItem.title = AppState.shared.isRecording ? "Stop Recording" : "Start Recording"
        }

        // Update mode checkmarks
        if let modesItem = menu.item(withTitle: "Mode"),
           let modesSubmenu = modesItem.submenu {
            for item in modesSubmenu.items {
                if let mode = item.representedObject as? Mode {
                    item.state = mode.key == AppState.shared.settings.defaultModeKey ? .on : .off
                }
            }
        }
    }

    @objc private func toggleRecording() {
        RecordingCoordinator.shared.toggleRecording()
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? Mode else { return }

        AppState.shared.settings.defaultModeKey = mode.key
        AppState.shared.currentMode = mode
        AppState.shared.saveSettings()

        print("✓ Selected mode: \(mode.name)")
    }

    @objc private func openHistory() {
        HistoryWindow.show()
    }

    @objc private func openSettings() {
        SettingsWindow.show()
    }
}

// MARK: - Window Helpers

class HistoryWindow {
    static private var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: HistoryView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "History"
        window.setContentSize(NSSize(width: 800, height: 600))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class SettingsWindow {
    static private var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)

        window.title = "Settings"
        window.setContentSize(NSSize(width: 600, height: 500))
        window.styleMask = [.titled, .closable, .resizable]
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

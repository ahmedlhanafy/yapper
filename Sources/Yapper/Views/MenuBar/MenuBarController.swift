import AppKit
import SwiftUI

/// Manages the menubar icon and menu
class MenuBarController {
    private weak var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let updaterController: UpdaterController

    init(statusItem: NSStatusItem?, updaterController: UpdaterController) {
        self.statusItem = statusItem
        self.updaterController = updaterController
        buildMenu()
    }

    func showMenu() {
        guard let button = statusItem?.button, let menu = menu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }

    private func buildMenu() {
        let menu = NSMenu()

        // Start/Stop Recording
        let recordItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = [.command, .shift]
        recordItem.target = self
        recordItem.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // Modes submenu
        let modesItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modesItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
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
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        menu.addItem(historyItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit Yapper",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        self.menu = menu
        // Don't set item.menu — we show it manually on right-click
        // so left-click can toggle recording

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
        guard let menu = menu else { return }

        // Update recording menu item (first item)
        if let recordItem = menu.item(at: 0) {
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

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates()
    }

    @objc private func openHistory() {
        SettingsWindow.show(tab: .history)
    }

    @objc private func openSettings() {
        SettingsWindow.show()
    }
}

// MARK: - Window Helpers

class SettingsWindow: NSObject, NSToolbarDelegate {
    static let shared = SettingsWindow()
    private var window: NSWindow?
    private var viewState: SettingsViewState?
    private var splitVC: NSSplitViewController?

    static func show(tab: SettingsView.Tab? = nil) {
        shared._show(tab: tab)
    }

    private func _show(tab: SettingsView.Tab? = nil) {
        if let existing = window {
            if let tab = tab {
                viewState?.selectedTab = tab
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Shared state
        let state = SettingsViewState(tab: tab ?? .general)
        self.viewState = state

        // Sidebar
        let sidebarView = SettingsSidebarView(viewState: state)
        let sidebarVC = NSHostingController(rootView: sidebarView)

        // Detail
        let detailView = SettingsDetailView(viewState: state)
        let detailVC = NSHostingController(rootView: detailView)

        // Split view controller
        let splitVC = NSSplitViewController()
        self.splitVC = splitVC

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 180
        sidebarItem.maximumThickness = 260
        sidebarItem.canCollapse = false

        let detailItem = NSSplitViewItem(viewController: detailVC)
        detailItem.minimumThickness = 400

        splitVC.addSplitViewItem(sidebarItem)
        splitVC.addSplitViewItem(detailItem)

        // Window
        let window = NSWindow(contentViewController: splitVC)
        window.title = ""
        window.setContentSize(NSSize(width: 820, height: 540))
        window.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified

        // Toolbar with tracking separator
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.delegate = self
        toolbar.showsBaselineSeparator = false
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == .sidebarTrackingSeparator, let splitView = splitVC?.splitView {
            return NSTrackingSeparatorToolbarItem(
                identifier: itemIdentifier,
                splitView: splitView,
                dividerIndex: 0
            )
        }
        return nil
    }
}

import Foundation
import AppKit
import SwiftUI

/// Manages app-wide appearance (light/dark mode)
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var effectiveAppearance: NSAppearance?

    private init() {}

    /// Apply the appearance based on current settings
    func applyAppearance() {
        let mode = AppState.shared.settings.appearanceMode
        applyAppearance(mode)
    }

    /// Apply a specific appearance mode
    func applyAppearance(_ mode: AppearanceMode) {
        let appearance: NSAppearance?

        switch mode {
        case .system:
            appearance = nil // Follow system
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        }

        // Apply to all windows
        DispatchQueue.main.async {
            NSApp.appearance = appearance

            // Update all existing windows
            for window in NSApp.windows {
                window.appearance = appearance
                window.invalidateShadow()
            }

            self.effectiveAppearance = appearance
            print("🎨 Applied appearance: \(mode.displayName)")
        }
    }

    /// Get the current effective color scheme
    var currentColorScheme: ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }
}

import SwiftUI

/// Compact always-visible recording indicator (kept for backwards compatibility)
struct MiniRecordingWindow: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @ObservedObject var coordinator = RecordingCoordinator.shared

    @State private var isHovered = false
    @State private var showingModeMenu = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            statusIndicator

            if isHovered || appState.isRecording {
                // Mode badge
                Text(appState.currentMode.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.secondary))

                // Controls
                controlButtons
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(radius: 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: statusColor.opacity(0.5), radius: 4)
    }

    private var statusColor: Color {
        switch coordinator.state {
        case .idle:
            return .gray
        case .recording:
            return .red
        case .downloadingModel, .transcribing, .processing:
            return .blue
        case .inserting:
            return .green
        case .done:
            return .green
        case .error:
            return .orange
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        HStack(spacing: 4) {
            // Record/Stop button
            Button(action: { coordinator.toggleRecording() }) {
                Image(systemName: appState.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help(appState.isRecording ? "Stop recording" : "Start recording")

            // Mode selector
            Menu {
                ForEach(appState.settings.modes, id: \.id) { mode in
                    Button(action: { selectMode(mode) }) {
                        HStack {
                            Text(mode.name)
                            if mode.key == appState.settings.defaultModeKey {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)
            .help("Change mode")

            // Expand button
            Button(action: { showLargeWindow() }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help("Show large window")
        }
    }

    private func selectMode(_ mode: Mode) {
        appState.settings.defaultModeKey = mode.key
        appState.currentMode = mode
        appState.saveSettings()
    }

    private func showLargeWindow() {
        // TODO: Show large recording window
        print("Show large recording window")
    }
}

// MARK: - Non-Snapping Panel

/// Custom NSPanel that implements manual dragging to avoid macOS window snapping/tiling
class NonSnappingPanel: NSPanel {
    private var dragStartMouseLocation: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        // Disable system-managed dragging - we'll handle it ourselves
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            // Start custom drag
            dragStartMouseLocation = NSEvent.mouseLocation
            dragStartWindowOrigin = frame.origin
            super.sendEvent(event)

        case .leftMouseDragged:
            // Custom drag handling - move window manually without system snapping
            if let startMouse = dragStartMouseLocation, let startOrigin = dragStartWindowOrigin {
                let currentMouse = NSEvent.mouseLocation
                let newOrigin = NSPoint(
                    x: startOrigin.x + (currentMouse.x - startMouse.x),
                    y: startOrigin.y + (currentMouse.y - startMouse.y)
                )
                setFrameOrigin(newOrigin)
            }
            // Don't call super - we're handling the drag ourselves

        case .leftMouseUp:
            dragStartMouseLocation = nil
            dragStartWindowOrigin = nil
            super.sendEvent(event)

        default:
            super.sendEvent(event)
        }
    }
}

// MARK: - Rounded Visual Effect View

/// Custom container that provides a properly masked visual effect background
class RoundedVisualEffectView: NSView {
    private let visualEffectView: NSVisualEffectView
    private let hostingView: NSView
    let cornerRadius: CGFloat

    init<Content: View>(rootView: Content, cornerRadius: CGFloat, size: NSSize) {
        self.cornerRadius = cornerRadius

        // Create visual effect view for the blurred background
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true

        // Create hosting view for SwiftUI content
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = CGColor.clear
        hostingView = hosting

        super.init(frame: NSRect(origin: .zero, size: size))

        wantsLayer = true
        layer?.backgroundColor = CGColor.clear

        // Add subviews
        addSubview(visualEffectView)
        addSubview(hostingView)

        // Setup constraints
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),

            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Apply rounded mask
        applyRoundedMask()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        applyRoundedMask()
    }

    private func applyRoundedMask() {
        let maskLayer = CAShapeLayer()
        maskLayer.path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        layer?.mask = maskLayer

        // Also mask the visual effect view
        let veMaskLayer = CAShapeLayer()
        veMaskLayer.path = CGPath(roundedRect: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        visualEffectView.layer?.mask = veMaskLayer
    }

    override var isOpaque: Bool {
        return false
    }
}

// MARK: - Window Controller

class MiniRecordingWindowController {
    static let shared = MiniRecordingWindowController()

    private var window: NSPanel?
    private var escapeMonitor: Any?
    private var previousApp: NSRunningApplication?

    func show() {
        // Save the currently focused app BEFORE showing our window
        // This allows us to restore focus when insertion happens
        previousApp = NSWorkspace.shared.frontmostApplication

        if let existing = window {
            existing.orderFront(nil)
            // DON'T activate - we want to keep focus on the original app
            return
        }

        // Get the current window style from settings
        let style = AppState.shared.settings.recordingWindowStyle

        // Create the appropriate view and size based on style
        let hostingView: NSView
        let windowWidth: CGFloat
        let windowHeight: CGFloat

        switch style {
        case .classic:
            let view = RecordingWindowContent()
            let size = NSSize(width: 380, height: 140)
            let container = RoundedVisualEffectView(rootView: view, cornerRadius: 20, size: size)
            hostingView = container
            windowWidth = 380
            windowHeight = 140

        case .mini:
            let view = CompactRecordingWindowContent()
            let size = NSSize(width: 90, height: 32)
            let container = RoundedVisualEffectView(rootView: view, cornerRadius: 16, size: size)
            hostingView = container
            windowWidth = 90
            windowHeight = 32
        }

        // Use custom NonSnappingPanel to avoid macOS window tiling/snapping
        let panel = NonSnappingPanel(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = NSColor.clear
        panel.hasShadow = true
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.tabbingMode = .disallowed

        // Position based on style
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x: CGFloat
            let y: CGFloat

            switch style {
            case .classic:
                // Center on screen, slightly above middle
                x = screenFrame.midX - (windowWidth / 2)
                y = screenFrame.midY - (windowHeight / 2) + 100

            case .mini:
                // Top center, below menu bar
                x = screenFrame.midX - (windowWidth / 2)
                y = screenFrame.maxY - windowHeight - 10
            }

            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.window = panel
        panel.orderFront(nil)
        // DON'T activate - the panel is non-activating so focus stays on original app

        // Setup escape key monitor
        setupEscapeMonitor()
    }

    func hide() {
        removeEscapeMonitor()
        window?.orderOut(nil)
        window = nil
    }

    /// Restore focus to the app that was active before recording started
    func restorePreviousApp() {
        if let app = previousApp {
            print("📍 Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate(options: [])
        }
        previousApp = nil
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private func setupEscapeMonitor() {
        // Use global monitor since the panel is non-activating (doesn't receive local events)
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                DispatchQueue.main.async {
                    RecordingCoordinator.shared.cancelRecording()
                    self?.hide()
                }
            }
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }
}

// MARK: - Preview

#Preview {
    MiniRecordingWindow()
        .frame(width: 250, height: 50)
        .padding()
}

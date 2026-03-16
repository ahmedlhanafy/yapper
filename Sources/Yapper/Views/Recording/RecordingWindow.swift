import SwiftUI

/// Content-only view for the recording window (background handled by AppKit)
struct RecordingWindowContent: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @ObservedObject var coordinator = RecordingCoordinator.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.15, count: 60)
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private let cornerRadius: CGFloat = 36

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    private var innerBorderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.5)
    }

    private var waveformGradient: LinearGradient {
        if appState.isRecording {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.3, blue: 0.35),
                    Color(red: 1.0, green: 0.5, blue: 0.4)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.3),
                    colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.2)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    var body: some View {
        ZStack {
            // Subtle glow when recording
            if appState.isRecording {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.red.opacity(glowOpacity * 0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
            }

            // Content
            VStack(spacing: 0) {
                if coordinator.state == .processing || coordinator.state == .transcribing {
                    processingOverlay
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 12)
                } else {
                    waveformArea
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 12)
                }

                Rectangle()
                    .fill(separatorColor)
                    .frame(height: 0.5)

                bottomToolbar
            }

            // Inner highlight
            RoundedRectangle(cornerRadius: cornerRadius - 1)
                .stroke(innerBorderColor, lineWidth: 1)
                .padding(1)

            // Border overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        }
        .frame(width: 380, height: 140)
        .onReceive(audioEngine.$currentLevel) { level in
            updateWaveform(level: level)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }

    // MARK: - Waveform Area

    private var waveformArea: some View {
        ZStack {
            // Waveform visualization - centered
            waveformVisualization
                .padding(.horizontal, 12)

            // Recording indicator (pulsing dot) - top left
            if appState.isRecording {
                VStack {
                    HStack {
                        recordingIndicator
                            .padding(.leading, 2)
                            .padding(.top, 2)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 65)
    }

    private var recordingIndicator: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(Color.red.opacity(0.2))
                .frame(width: 16, height: 16)
                .scaleEffect(pulseScale)

            // Inner solid dot
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.35, blue: 0.35), Color.red],
                        center: .center,
                        startRadius: 0,
                        endRadius: 5
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: Color.red.opacity(0.6), radius: 4)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.4
            }
        }
    }

    private var waveformVisualization: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<waveformLevels.count, id: \.self) { index in
                    waveformBar(for: index)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .animation(.spring(response: 0.1, dampingFraction: 0.7), value: waveformLevels)
    }

    private func waveformBar(for index: Int) -> some View {
        let height = barHeight(for: index)

        return RoundedRectangle(cornerRadius: 2)
            .fill(waveformGradient)
            .frame(width: 3, height: height)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard appState.isRecording else {
            // Idle state - subtle wave pattern
            let wave = sin(Double(index) * 0.3) * 2 + 4
            return CGFloat(wave)
        }

        let level = waveformLevels[index]
        return max(4, min(45, level * 55))
    }

    private func updateWaveform(level: Float) {
        guard appState.isRecording else { return }

        var newLevels = waveformLevels
        newLevels.removeFirst()

        // Smoothed variation for organic feel
        let baseLevel = CGFloat(level)
        let variation = CGFloat.random(in: 0.8...1.2)
        newLevels.append(baseLevel * variation)

        waveformLevels = newLevels
    }

    // MARK: - Processing Overlay

    @State private var brainOpacity: Double = 0.3

    private var processingOverlay: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain")
                .font(.system(size: 24))
                .foregroundColor(coordinator.state == .processing ? .purple : .blue)
                .opacity(brainOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        brainOpacity = 1.0
                    }
                }
                .onDisappear {
                    brainOpacity = 0.3
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(coordinator.state == .transcribing ? "Transcribing..." : "Thinking...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)

                Text(coordinator.state == .transcribing ? "Converting speech to text" : "Processing with AI")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(height: 65)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            // App branding - minimal
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))

                Text("Yapper")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.leading, 18)

            Spacer()

            // Action hints with refined key caps
            HStack(spacing: 16) {
                ActionBadge(label: "Stop", keys: ["⌥", "Space"])
                ActionBadge(label: "Cancel", keys: ["esc"])
            }
            .padding(.trailing, 18)
        }
        .frame(height: 40)
    }
}

// MARK: - Action Badge

struct ActionBadge: View {
    let label: String
    let keys: [String]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.6))

            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    KeyCap(key: key)
                }
            }
        }
    }
}

// MARK: - Key Cap

struct KeyCap: View {
    let key: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(colorScheme == .dark ? .white.opacity(0.65) : .black.opacity(0.55))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

/// Backwards compatibility alias
typealias RecordingWindow = RecordingWindowContent

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        RecordingWindowContent()
    }
    .frame(width: 500, height: 250)
}

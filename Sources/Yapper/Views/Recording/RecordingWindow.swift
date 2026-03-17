import SwiftUI

/// Content-only view for the recording window (background handled by AppKit)
struct RecordingWindowContent: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @ObservedObject var coordinator = RecordingCoordinator.shared

    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.15, count: 60)
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var shimmerRotation: Double = 0

    private let cornerRadius: CGFloat = 20

    // Monochrome silver palette
    private let goldLight = Color(red: 0.85, green: 0.85, blue: 0.88)
    private let goldDark = Color(red: 0.55, green: 0.55, blue: 0.6)
    private let warmWhite = Color(red: 0.95, green: 0.95, blue: 0.97)

    private var borderColor: Color {
        goldDark.opacity(0.3)
    }

    private var waveformGradient: LinearGradient {
        if appState.isRecording {
            return LinearGradient(
                colors: [goldDark, goldLight],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.12)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.1))

            // Warm glow when recording
            if appState.isRecording {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [
                                goldDark.opacity(glowOpacity * 0.12),
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
                    .fill(goldDark.opacity(0.12))
                    .frame(height: 0.5)

                bottomToolbar
            }

            // Border — shimmer when processing, static otherwise
            if coordinator.state == .processing || coordinator.state == .transcribing {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                goldLight.opacity(0.6),
                                goldDark.opacity(0.1),
                                Color.clear,
                                Color.clear,
                                goldDark.opacity(0.1),
                                goldLight.opacity(0.6),
                            ],
                            center: .center,
                            angle: .degrees(shimmerRotation)
                        ),
                        lineWidth: 1.5
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [goldDark.opacity(0.35), goldDark.opacity(0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
        }
        .frame(width: 380, height: 140)
        .shadow(color: Color.black.opacity(0.5), radius: 20, y: 8)
        .onReceive(audioEngine.$currentLevel) { level in
            updateWaveform(level: level)
        }
        .onChange(of: coordinator.state) { newState in
            if newState == .processing || newState == .transcribing {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerRotation = 360
                }
            } else {
                shimmerRotation = 0
            }
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
            waveformVisualization
                .padding(.horizontal, 12)

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
            Circle()
                .fill(goldLight.opacity(0.2))
                .frame(width: 16, height: 16)
                .scaleEffect(pulseScale)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [goldLight, goldDark],
                        center: .center,
                        startRadius: 0,
                        endRadius: 5
                    )
                )
                .frame(width: 8, height: 8)
                .shadow(color: goldLight.opacity(0.6), radius: 4)
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
            HStack(spacing: 2) {
                ForEach(0..<mirroredLevels.count, id: \.self) { index in
                    waveformBar(for: index)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .animation(.spring(response: 0.1, dampingFraction: 0.7), value: waveformLevels)
    }

    // Mirror levels: center is newest, spreads outward both sides
    private var mirroredLevels: [CGFloat] {
        let half = Array(waveformLevels.suffix(30).reversed())
        return half.reversed() + half
    }

    private func waveformBar(for index: Int) -> some View {
        let levels = mirroredLevels
        let height = barHeight(level: levels[index], index: index, total: levels.count)

        return RoundedRectangle(cornerRadius: 1)
            .fill(waveformGradient)
            .frame(width: 2, height: height)
    }

    private func barHeight(level: CGFloat, index: Int, total: Int) -> CGFloat {
        guard appState.isRecording else {
            // Idle: gentle curve peaking at center
            let center = Double(total) / 2.0
            let dist = abs(Double(index) - center) / center
            let wave = (1.0 - dist) * 4 + 3
            return CGFloat(wave)
        }

        return max(3, min(45, level * 55))
    }

    private func updateWaveform(level: Float) {
        guard appState.isRecording else { return }

        var newLevels = waveformLevels
        newLevels.removeFirst()

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
                .foregroundColor(goldLight)
                .opacity(brainOpacity)
                .shadow(color: goldLight.opacity(0.4), radius: 6)
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
                    .foregroundColor(warmWhite)

                Text(coordinator.state == .transcribing ? "Converting speech to text" : "Processing with AI")
                    .font(.system(size: 11))
                    .foregroundColor(warmWhite.opacity(0.5))
            }

            Spacer()
        }
        .frame(height: 65)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(goldDark.opacity(0.5))

                Text("Yapper")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(goldDark.opacity(0.4))
            }
            .padding(.leading, 18)

            Spacer()

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

    private let goldDark = Color(red: 0.55, green: 0.55, blue: 0.6)

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.45))

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

    private let goldDark = Color(red: 0.55, green: 0.55, blue: 0.6)

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundColor(Color.white.opacity(0.55))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(goldDark.opacity(0.2), lineWidth: 0.5)
            )
    }
}

/// Backwards compatibility alias
typealias RecordingWindow = RecordingWindowContent

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        RecordingWindowContent()
    }
    .frame(width: 500, height: 250)
}

import SwiftUI

/// Content-only compact recording indicator (background handled by AppKit)
struct CompactRecordingWindowContent: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @Environment(\.colorScheme) var colorScheme

    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.15, count: 10)
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private var waveformGradient: LinearGradient {
        if appState.isRecording {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.35, blue: 0.4),
                    Color(red: 1.0, green: 0.5, blue: 0.45)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [
                    colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3),
                    colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08)
    }

    private var innerBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.4)
    }

    var body: some View {
        ZStack {
            // Subtle recording glow
            if appState.isRecording {
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(glowOpacity * 0.1), Color.clear],
                            center: .leading,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
            }

            // Content
            HStack(spacing: 8) {
                recordingDot
                waveformVisualization
                    .frame(width: 50, height: 16)
            }

            // Inner border
            Capsule()
                .stroke(innerBorderColor, lineWidth: 0.5)
                .padding(1)

            // Outer border
            Capsule()
                .stroke(borderColor, lineWidth: 0.5)
        }
        .frame(width: 90, height: 32)
        .onReceive(audioEngine.$currentLevel) { level in
            updateWaveform(level: level)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
        }
    }

    private var recordingDot: some View {
        ZStack {
            Circle()
                .fill(appState.isRecording ? Color.red.opacity(0.2) : Color.clear)
                .frame(width: 12, height: 12)
                .scaleEffect(appState.isRecording ? pulseScale : 1.0)

            Circle()
                .fill(
                    appState.isRecording
                        ? RadialGradient(
                            colors: [Color(red: 1.0, green: 0.4, blue: 0.4), Color.red],
                            center: .center,
                            startRadius: 0,
                            endRadius: 4
                        )
                        : RadialGradient(
                            colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 4
                        )
                )
                .frame(width: 6, height: 6)
                .shadow(color: appState.isRecording ? Color.red.opacity(0.5) : Color.clear, radius: 3)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.5
            }
        }
    }

    private var waveformVisualization: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<waveformLevels.count, id: \.self) { index in
                waveformBar(for: index)
            }
        }
        .animation(.spring(response: 0.08, dampingFraction: 0.7), value: waveformLevels)
    }

    private func waveformBar(for index: Int) -> some View {
        let height = barHeight(for: index)

        return RoundedRectangle(cornerRadius: 1.5)
            .fill(waveformGradient)
            .frame(width: 2.5, height: height)
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard appState.isRecording else {
            let wave = sin(Double(index) * 0.4) * 1 + 3
            return CGFloat(wave)
        }

        let level = waveformLevels[index]
        return max(3, min(14, level * 18))
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
}

/// Backwards compatibility alias
typealias CompactRecordingWindow = CompactRecordingWindowContent

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        CompactRecordingWindowContent()
    }
    .frame(width: 200, height: 100)
}

import SwiftUI

/// Content-only compact recording indicator (background handled by AppKit)
struct CompactRecordingWindowContent: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var audioEngine = AudioEngine.shared
    @ObservedObject var coordinator = RecordingCoordinator.shared

    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.15, count: 10)
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var brainOpacity: Double = 0.3
    @State private var shimmerRotation: Double = 0
    @State private var demoTimer: Timer?
    @State private var showModeName = false
    @State private var displayedModeName = ""

    private let cornerRadius: CGFloat = 16
    private let silverLight = Color(red: 0.85, green: 0.85, blue: 0.88)
    private let silverDark = Color(red: 0.55, green: 0.55, blue: 0.6)

    private var isDemoMode: Bool { appState.settings.demoMode }
    private var isActive: Bool { appState.isRecording || isDemoMode }

    private var isProcessing: Bool {
        coordinator.state == .processing || coordinator.state == .transcribing || coordinator.state == .downloadingModel
    }

    private var waveformColor: Color {
        isActive ? silverLight : Color.white.opacity(0.2)
    }

    var body: some View {
        ZStack {
            // Background
            Capsule()
                .fill(Color(red: 0.08, green: 0.08, blue: 0.1))

            // Glow when recording
            if isActive {
                Capsule()
                    .fill(
                        RadialGradient(
                            colors: [silverDark.opacity(glowOpacity * 0.12), Color.clear],
                            center: .leading,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
            }

            // Content
            if showModeName {
                Text(displayedModeName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(silverLight)
                    .transition(.opacity)
            } else if case .error = coordinator.state {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            } else if isProcessing {
                HStack(spacing: 6) {
                    if coordinator.state == .downloadingModel {
                        Text("\(Int(coordinator.downloadProgress * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(silverLight)
                    } else {
                        Image(systemName: "brain")
                            .font(.system(size: 12))
                            .foregroundColor(silverLight)
                            .opacity(brainOpacity)
                            .shadow(color: silverLight.opacity(0.3), radius: 3)
                        Text(coordinator.state == .transcribing ? "..." : "AI")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(silverLight.opacity(0.7))
                    }
                }
            } else {
                HStack(spacing: 8) {
                    recordingDot
                    waveformVisualization
                        .frame(width: 50, height: 16)
                }
            }

            // Border — shimmer when processing
            if isProcessing {
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                silverLight.opacity(0.6),
                                silverDark.opacity(0.1),
                                Color.clear,
                                Color.clear,
                                silverDark.opacity(0.1),
                                silverLight.opacity(0.6),
                            ],
                            center: .center,
                            angle: .degrees(shimmerRotation)
                        ),
                        lineWidth: 1.5
                    )
            } else {
                Capsule()
                    .strokeBorder(silverDark.opacity(0.25), lineWidth: 0.5)
            }
        }
        .frame(width: 90, height: 32)
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
        .onReceive(audioEngine.$currentLevel) { level in
            updateWaveform(level: level)
        }
        .onChange(of: coordinator.state) { newState in
            if newState == .processing || newState == .transcribing || newState == .downloadingModel {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerRotation = 360
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    brainOpacity = 1.0
                }
            } else {
                shimmerRotation = 0
                brainOpacity = 0.3
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.5
            }
            startDemoTimerIfNeeded()
        }
        .onChange(of: isDemoMode) { demo in
            if demo { startDemoTimerIfNeeded() } else { stopDemoTimer() }
        }
        .onChange(of: appState.settings.defaultModeKey) { _ in
            displayedModeName = appState.currentMode.name
            withAnimation(.easeIn(duration: 0.15)) { showModeName = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) { showModeName = false }
            }
        }
        .onDisappear { stopDemoTimer() }
    }

    private var recordingDot: some View {
        ZStack {
            Circle()
                .fill(silverLight.opacity(0.2))
                .frame(width: 12, height: 12)
                .scaleEffect(isActive ? pulseScale : 1.0)

            Circle()
                .fill(
                    RadialGradient(
                        colors: isActive
                            ? [silverLight, silverDark]
                            : [Color.gray.opacity(0.4), Color.gray.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 6, height: 6)
                .shadow(color: isActive ? silverLight.opacity(0.5) : Color.clear, radius: 3)
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
        let mirrored = mirroredLevels
        return HStack(spacing: 2) {
            ForEach(0..<mirrored.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(waveformColor)
                    .frame(width: 2, height: barHeight(level: mirrored[index], index: index, total: mirrored.count))
            }
        }
        .animation(.spring(response: 0.08, dampingFraction: 0.7), value: waveformLevels)
    }

    private var mirroredLevels: [CGFloat] {
        let half = Array(waveformLevels.suffix(5).reversed())
        return half.reversed() + half
    }

    private func barHeight(level: CGFloat, index: Int, total: Int) -> CGFloat {
        guard isActive else {
            let center = Double(total) / 2.0
            let dist = abs(Double(index) - center) / center
            return CGFloat((1.0 - dist) * 3 + 2)
        }
        return max(3, min(14, level * 18))
    }

    private func startDemoTimerIfNeeded() {
        guard isDemoMode, demoTimer == nil else { return }
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [self] _ in
            var newLevels = self.waveformLevels
            newLevels.removeFirst()
            let t: Double = Date().timeIntervalSinceReferenceDate
            let a: CGFloat = CGFloat(sin(t * 4.0)) * 0.2
            let b: CGFloat = CGFloat(sin(t * 8.5)) * 0.15
            let level: CGFloat = 0.35 + a + b
            let jitter: CGFloat = CGFloat.random(in: 0.85...1.15)
            newLevels.append(level * jitter)
            self.waveformLevels = newLevels
        }
    }

    private func stopDemoTimer() {
        demoTimer?.invalidate()
        demoTimer = nil
    }

    private func updateWaveform(level: Float) {
        guard isActive else { return }

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

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CompactRecordingWindowContent()
    }
    .frame(width: 200, height: 100)
}

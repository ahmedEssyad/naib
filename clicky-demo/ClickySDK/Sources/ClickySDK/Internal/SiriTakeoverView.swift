import SwiftUI

// Full-screen Siri-style takeover. Visible during .listening and .thinking.
// Dims the app, shows an animated waveform, the live partial transcript,
// suggestion chips for the current screen, and a Cancel button.
struct SiriTakeoverView: View {
    @EnvironmentObject private var manager: AssistantManager

    var body: some View {
        ZStack {
            // Dim layer — tap to cancel.
            Color.black.opacity(0.55)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { manager.cancelTakeover() }

            VStack(spacing: 28) {
                Spacer(minLength: 60)

                Waveform(level: micLevel, isAmbient: isThinking)
                    .frame(height: 96)
                    .padding(.horizontal, 40)

                statusLabel
                    .padding(.horizontal, 32)

                if !isThinking {
                    suggestionsRow
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    manager.cancelTakeover()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .transition(.opacity)
    }

    private var isListening: Bool {
        if case .listening = manager.phase { return true }
        return false
    }

    private var isThinking: Bool {
        if case .thinking = manager.phase { return true }
        return false
    }

    private var micLevel: Float {
        if case .listening(_, let level) = manager.phase { return level }
        return 0
    }

    private var partialTranscript: String {
        if case .listening(let text, _) = manager.phase { return text }
        if case .thinking(let prompt) = manager.phase { return prompt }
        return ""
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isThinking {
            VStack(spacing: 10) {
                Text("\u{201C}\(partialTranscript)\u{201D}")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Working on it…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }
        } else if partialTranscript.isEmpty {
            Text("Listening\u{2026}")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
        } else {
            Text(partialTranscript)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var suggestionsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(manager.suggestionsForCurrentScreen(), id: \.self) { suggestion in
                    Button {
                        manager.submitPrompt(suggestion)
                    } label: {
                        HStack {
                            Text(suggestion)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// Animated multi-bar waveform. While listening, bar heights are driven by
// the mic RMS level. While thinking, bars animate in a gentle ambient
// sine pattern so the user knows the assistant is still alive.
private struct Waveform: View {
    let level: Float
    let isAmbient: Bool
    private let barCount = 7
    @State private var phaseOffset: Double = 0

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 8) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.36, blue: 1.0),
                                Color(red: 0.31, green: 0.65, blue: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 16, height: height(forBar: index, time: time))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func height(forBar index: Int, time: TimeInterval) -> CGFloat {
        let baseline: CGFloat = 16
        let maxHeight: CGFloat = 96

        // Each bar gets its own phase so they don't all move together.
        let speed: Double = isAmbient ? 1.8 : 5.0
        let offset = Double(index) * 0.6
        let raw = (sin(time * speed + offset) + 1) / 2  // 0…1

        let intensity: CGFloat
        if isAmbient {
            intensity = 0.25 + CGFloat(raw) * 0.25  // gentle 0.25-0.5
        } else {
            // Blend mic level with idle motion so it never goes flat-zero.
            let micComponent = CGFloat(level) * 0.85
            let motionComponent = CGFloat(raw) * 0.25
            intensity = max(0.12, min(1.0, micComponent + motionComponent))
        }
        return baseline + (maxHeight - baseline) * intensity
    }
}

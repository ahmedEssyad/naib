import SwiftUI

// Renders the pulsing glow around the currently highlighted element and,
// when set, a small tooltip above it. The step navigation UI lives in
// WalkthroughStepPill / AssistantStatusPill — this overlay only draws the
// visual indicator on the element itself.
struct HighlightOverlayView: View {
    @EnvironmentObject private var elementRegistry: ElementRegistry
    @EnvironmentObject private var assistantManager: AssistantManager
    @State private var pulse: CGFloat = 0.8

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                if let elementId = assistantManager.highlightedElementId,
                   let frame = elementRegistry.frame(for: elementId) {
                    glowRectangle(frame: frame)
                    if let tooltip = effectiveTooltip {
                        tooltipBubble(text: tooltip, anchorFrame: frame)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = 1.15
            }
        }
    }

    // Only show a tooltip when one was explicitly set (via the `tooltip`
    // tool call). Guide-mode step text already lives in the bottom step
    // pill — duplicating it as a floating bubble was redundant and made
    // small elements look cluttered. Acting mode uses the top status pill.
    private var effectiveTooltip: String? {
        assistantManager.tooltipText
    }

    private func glowRectangle(frame: CGRect) -> some View {
        let inset: CGFloat = 6
        let expandedFrame = frame.insetBy(dx: -inset, dy: -inset)
        return RoundedRectangle(cornerRadius: 14)
            .stroke(Color.blue.opacity(0.95), lineWidth: 3)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.12))
            )
            .frame(width: expandedFrame.width, height: expandedFrame.height)
            .position(x: expandedFrame.midX, y: expandedFrame.midY)
            .shadow(color: Color.blue.opacity(0.7), radius: 18)
            .scaleEffect(pulse)
            .animation(.easeInOut(duration: 0.25), value: frame)
    }

    private func tooltipBubble(text: String, anchorFrame: CGRect) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
            .position(
                x: anchorFrame.midX,
                y: max(anchorFrame.minY - 28, 60)
            )
    }
}

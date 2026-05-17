import SwiftUI

// Thin router. Picks which agent surface to render based on the
// AssistantManager's `phase`. Each surface is its own file:
//
//   .idle      → AssistantTriggerPill (small bottom pill)
//   .listening → SiriTakeoverView      (fullscreen mic UI)
//   .thinking  → SiriTakeoverView      (fullscreen thinking UI)
//   .acting    → AssistantStatusPill   (slim top pill, app stays usable)
//   .guiding   → WalkthroughStepPill   (compact bottom pill, manual nav)
struct AssistantOverlayView: View {
    @EnvironmentObject private var manager: AssistantManager

    var body: some View {
        ZStack {
            switch manager.phase {
            case .idle:
                // Hide the trigger pill while a single-shot highlight is
                // still on screen — otherwise the chip overlaps whatever
                // Claude is pointing at near the bottom of the screen.
                if manager.highlightedElementId == nil {
                    AssistantTriggerPill()
                        .transition(.opacity)
                }
            case .listening, .thinking:
                SiriTakeoverView()
                    .transition(.opacity)
            case .acting:
                AssistantStatusPill()
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .guiding:
                WalkthroughStepPill()
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: phaseSnapshot)
    }

    // A compact value the animation can watch — Equatable + ignores
    // associated values to avoid jitter from rapid mic-level updates.
    private var phaseSnapshot: Int {
        switch manager.phase {
        case .idle: return 0
        case .listening: return 1
        case .thinking: return 2
        case .acting: return 3
        case .guiding: return 4
        }
    }
}

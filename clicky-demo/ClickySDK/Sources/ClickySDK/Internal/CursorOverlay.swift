import SwiftUI

// The virtual cursor — a blue dot that flies between elements when the
// assistant is acting on the user's behalf. Driven entirely by
// assistantManager.cursorPosition (animates) and cursorIsClicking (pulse).
struct CursorOverlay: View {
    @EnvironmentObject private var assistantManager: AssistantManager
    @State private var trailPulse: Bool = false

    var body: some View {
        GeometryReader { _ in
            if let position = assistantManager.cursorPosition {
                ZStack {
                    // Soft outer halo
                    Circle()
                        .fill(Color.blue.opacity(0.22))
                        .frame(width: 48, height: 48)
                        .scaleEffect(assistantManager.cursorIsClicking ? 1.6 : 1.0)
                        .opacity(assistantManager.cursorIsClicking ? 0.0 : 1.0)
                        .animation(.easeOut(duration: 0.35), value: assistantManager.cursorIsClicking)

                    // Inner dot
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                        .shadow(color: Color.blue.opacity(0.6), radius: 12, x: 0, y: 4)
                        .scaleEffect(assistantManager.cursorIsClicking ? 0.7 : 1.0)
                        .animation(.spring(response: 0.18, dampingFraction: 0.55), value: assistantManager.cursorIsClicking)
                }
                .position(position)
                .animation(.spring(response: 0.55, dampingFraction: 0.75), value: position)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

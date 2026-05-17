import SwiftUI

// Small bottom-center pill, visible only when phase == .idle.
// Tapping it opens the Siri-style takeover.
struct AssistantTriggerPill: View {
    @EnvironmentObject private var manager: AssistantManager

    var body: some View {
        VStack {
            Spacer()
            Button {
                manager.openTakeover()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.55, green: 0.36, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 28, height: 28)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Ask the assistant")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))
                }
                .padding(.leading, 6)
                .padding(.trailing, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
    }
}

import SwiftUI

// Slim top status pill, visible during .acting (auto-executed walkthrough).
// Shows a spinning indicator + current step's label + step counter + ✕ cancel.
struct AssistantStatusPill: View {
    @EnvironmentObject private var manager: AssistantManager
    @State private var spinAngle: Double = 0

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                spinningDot
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Step \(current) of \(total)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer(minLength: 8)
                Button {
                    manager.dismissWalkthrough()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.82))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                spinAngle = 360
            }
        }
    }

    private var spinningDot: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                .frame(width: 16, height: 16)
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.36, blue: 1.0), Color(red: 0.31, green: 0.65, blue: 1.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(spinAngle))
        }
    }

    private var label: String {
        if case .acting(let l, _, _) = manager.phase { return l }
        return ""
    }

    private var current: Int {
        if case .acting(_, let c, _) = manager.phase { return c }
        return 0
    }

    private var total: Int {
        if case .acting(_, _, let t) = manager.phase { return t }
        return 0
    }
}

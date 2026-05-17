import SwiftUI

// Bottom-anchored compact pill for MANUAL walkthroughs (guide mode).
// Visible during .guiding. Shows the current step text + Back / Next / Close.
// Sits in the safe area, leaving room for the host app's own bottom bars.
struct WalkthroughStepPill: View {
    @EnvironmentObject private var manager: AssistantManager

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("STEP \(currentIndex + 1) OF \(total)")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.3)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    dotProgress
                    Spacer().frame(width: 8)
                    Button {
                        manager.dismissWalkthrough()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                if let stepText = manager.currentStep?.text, !stepText.isEmpty {
                    Text(stepText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button {
                        manager.goToPreviousStep()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .bold))
                            Text("Back")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(currentIndex == 0 ? Color.white.opacity(0.35) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.white.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == 0)

                    Button {
                        manager.advanceToNextStep()
                    } label: {
                        HStack(spacing: 6) {
                            Text(isLastStep ? "Done" : "Next")
                                .font(.system(size: 13, weight: .semibold))
                            if !isLastStep {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                        }
                        .foregroundColor(Color(red: 0.07, green: 0.09, blue: 0.15))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(Color.white)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.black.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var dotProgress: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentIndex ? 14 : 5, height: 4)
                    .animation(.easeInOut(duration: 0.2), value: currentIndex)
            }
        }
    }

    private var currentIndex: Int {
        if case .guiding(let i, _) = manager.phase { return i }
        return 0
    }

    private var total: Int {
        if case .guiding(_, let t) = manager.phase { return t }
        return 0
    }

    private var isLastStep: Bool {
        currentIndex >= total - 1
    }
}

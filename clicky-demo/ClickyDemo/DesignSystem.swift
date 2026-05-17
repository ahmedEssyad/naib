import SwiftUI

// Shared design tokens. All UI references these so the look is consistent
// and easy to retune in one place.
enum DS {
    enum Colors {
        static let background = Color(red: 0.97, green: 0.97, blue: 0.98)
        static let surface = Color.white
        static let surfaceElevated = Color.white
        static let border = Color(red: 0.92, green: 0.92, blue: 0.95)

        static let textPrimary = Color(red: 0.07, green: 0.09, blue: 0.15)
        static let textSecondary = Color(red: 0.42, green: 0.45, blue: 0.52)
        static let textTertiary = Color(red: 0.62, green: 0.65, blue: 0.72)

        static let brandPrimary = Color(red: 0.31, green: 0.27, blue: 0.90) // indigo
        static let brandSecondary = Color(red: 0.55, green: 0.36, blue: 1.0) // violet
        static let accentGreen = Color(red: 0.13, green: 0.78, blue: 0.42)
        static let accentRed = Color(red: 0.96, green: 0.27, blue: 0.34)
        static let accentOrange = Color(red: 1.0, green: 0.58, blue: 0.0)

        static let heroGradient = LinearGradient(
            colors: [
                Color(red: 0.16, green: 0.13, blue: 0.55),
                Color(red: 0.31, green: 0.27, blue: 0.90),
                Color(red: 0.55, green: 0.36, blue: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 14
        static let large: CGFloat = 20
        static let xlarge: CGFloat = 28
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(enabled ? DS.Colors.brandPrimary : DS.Colors.textTertiary)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.large)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.sm) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(0.85)
            }
            configuration.label
                .font(.lexisBodyM)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            Group {
                if configuration.isPressed {
                    LinearGradient.hero.opacity(0.8)
                } else {
                    LinearGradient.hero
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lexisBodyM)
            .foregroundColor(.moonPearl)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.glassBorder)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.glassBorderActive, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = .textSecondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lexisBodyM)
            .foregroundColor(color.opacity(configuration.isPressed ? 0.6 : 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Convenience View Extensions

extension View {
    func primaryStyle(isLoading: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
    }

    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }

    func ghostStyle(color: Color = .textSecondary) -> some View {
        self.buttonStyle(GhostButtonStyle(color: color))
    }
}

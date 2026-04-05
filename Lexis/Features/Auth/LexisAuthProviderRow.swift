import SwiftUI

/// Three equal sign-in affordances: Google, Sign in with Apple (programmatic), Email sheet.
struct LexisAuthProviderRow: View {
    var vm: AuthViewModel
    var onGoogle: () -> Void
    var onEmail: () -> Void

    private let chipHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: Spacing.md) {
            googleChip
            appleChip
            emailChip
        }
        .padding(.horizontal, Spacing.xl)
        .disabled(vm.isLoading)
    }

    private var googleChip: some View {
        Button {
            Haptics.impact(.medium)
            onGoogle()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.surfaceCard)
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.glassBorder, lineWidth: 1)
                Image("GoogleSignInGlyph")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: chipHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Google")
    }

    private var appleChip: some View {
        Button {
            Haptics.impact(.medium)
            vm.performSignInWithApple()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.surfaceCard)
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.glassBorder, lineWidth: 1)
                Image(systemName: "apple.logo")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color.moonPearl)
            }
            .frame(maxWidth: .infinity)
            .frame(height: chipHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with Apple")
    }

    private var emailChip: some View {
        Button {
            Haptics.impact(.medium)
            onEmail()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(Color.surfaceCard)
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.glassBorder, lineWidth: 1)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(LinearGradient.hero)
            }
            .frame(maxWidth: .infinity)
            .frame(height: chipHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sign in with email")
    }
}

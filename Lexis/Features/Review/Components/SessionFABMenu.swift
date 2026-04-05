import SwiftUI

/// In-session hub (wireframe FAB): subscription + settings without leaving the session shell.
struct SessionFABMenu: View {
    @Binding var isExpanded: Bool
    let bottomInset: CGFloat
    let onSubscription: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.md) {
            if isExpanded {
                fabMiniButton(
                    icon: "crown.fill",
                    label: "Subscription",
                    tint: .amberGlow
                ) {
                    collapseThen { onSubscription() }
                }
                fabMiniButton(
                    icon: "gearshape.fill",
                    label: "Settings",
                    tint: .cobaltBlue
                ) {
                    collapseThen { onSettings() }
                }
            }

            Button {
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.inkBlack)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.navyBlue, Color.cobaltBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            }
            .accessibilityLabel(isExpanded ? "Close menu" : "More actions")
        }
        .padding(.trailing, Spacing.lg)
        .padding(.bottom, bottomInset)
    }

    private func fabMiniButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: Spacing.md) {
                Text(label)
                    .font(.lexisCaptionM)
                    .foregroundColor(.moonPearl)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 44, height: 44)
                    .background(Color.surfaceCard)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.glassBorder, lineWidth: 1))
            }
            .padding(.leading, Spacing.lg)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
            .background(Color.deepNavy.opacity(0.92))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.glassBorder.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func collapseThen(_ work: @escaping () -> Void) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isExpanded = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            work()
        }
    }
}

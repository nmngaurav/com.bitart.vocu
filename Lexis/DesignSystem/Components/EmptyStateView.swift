import SwiftUI

// MARK: - Empty & Error State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(LinearGradient.hero.opacity(0.12))
                    .frame(width: 80, height: 80)
                Text(icon)
                    .font(.system(size: 34))
            }

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.lexisH2)
                    .foregroundColor(.moonPearl)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.lexisBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            if let title = actionTitle, let action = action {
                Button(title, action: action)
                    .primaryStyle()
                    .frame(width: 200)
            }
        }
        .padding(Spacing.xxxl)
    }
}

// MARK: - Error State with Retry

struct NetworkErrorView: View {
    var retry: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "📡",
            title: "Connection Issue",
            subtitle: "We couldn't reach the server.\nCheck your connection and try again.",
            actionTitle: "Retry",
            action: retry
        )
    }
}

import SwiftUI

private enum FeedbackCardDefaults {
    static let edgeSwipeHintShownKey = "vocuFeedbackEdgeSwipeHintShown"
}

struct FeedbackCardView: View {
    let card: ReviewQueueCard
    let onRate: (CardRating) -> Void
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var optionsVisible = false
    @State private var showEdgeHint = false
    @State private var edgeHintOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .leading) {
            ReviewSessionCardAtmosphere()

            LinearGradient(
                colors: [Color.cobaltBlue.opacity(0.28), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 5)
            .allowsHitTesting(false)

            edgeSwipeBackZone

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: Spacing.xl) {
                    Text("How well did you know this?")
                        .font(.lexisH2)
                        .foregroundColor(.moonPearl)
                        .multilineTextAlignment(.center)

                    ratingOptions
                }
                .padding(.vertical, Spacing.xxl)
                .padding(.horizontal, Spacing.xl)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 15)
                .padding(.horizontal, Spacing.lg)
                .opacity(optionsVisible ? 1 : 0)
                .offset(y: optionsVisible ? 0 : 16)

                Spacer(minLength: 0)
            }

            if showEdgeHint {
                VStack {
                    HStack {
                        ReviewSessionHintCapsule(
                            systemImage: "arrow.left",
                            title: "Swipe in from the left edge",
                            subtitle: "Return to the word card"
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, Spacing.md)
                    .padding(.top, Spacing.lg)
                    Spacer(minLength: 0)
                }
                .opacity(edgeHintOpacity)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            "Swipe from the left edge to return to the word. Then choose how well you knew it."
        )
        .accessibilityAction(named: Text("Back to word")) {
            Haptics.impact(.light)
            onBack()
        }
        .onAppear {
            if reduceMotion {
                optionsVisible = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86).delay(0.05)) {
                    optionsVisible = true
                }
            }
            scheduleOneTimeEdgeHintIfNeeded()
        }
    }

    private var edgeSwipeBackZone: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 32)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            guard value.translation.width > 56,
                                  abs(value.translation.height) < 100 else { return }
                            Haptics.impact(.light)
                            onBack()
                        }
                )
            Spacer(minLength: 0)
        }
        .allowsHitTesting(true)
    }

    private func scheduleOneTimeEdgeHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: FeedbackCardDefaults.edgeSwipeHintShownKey) else { return }
        showEdgeHint = true
        edgeHintOpacity = 0
        withAnimation(.easeOut(duration: 0.38)) {
            edgeHintOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.45)) {
                edgeHintOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                showEdgeHint = false
                UserDefaults.standard.set(true, forKey: FeedbackCardDefaults.edgeSwipeHintShownKey)
            }
        }
    }

    private var ratingOptions: some View {
        VStack(spacing: Spacing.md) {
            ForEach([CardRating.tooSoon, .almost, .gotIt], id: \.rawValue) { rating in
                RatingOptionButton(rating: rating) {
                    Haptics.impact(rating == .gotIt ? .medium : .light)
                    onRate(rating)
                }
                .accessibilityLabel("\(rating.label). \(rating.description)")
            }
        }
    }
}

private struct RatingOptionButton: View {
    let rating: CardRating
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [rating.accentColor.opacity(0.28), rating.accentColor.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 26
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: rating.iconName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(rating.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(rating.label)
                        .font(.lexisBodyM)
                        .foregroundColor(.moonPearl)
                    Text(rating.description)
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer(minLength: Spacing.sm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 66)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [rating.accentColor.opacity(0.65), rating.accentColor.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: rating.accentColor.opacity(0.14), radius: 16, y: 8)
        }
        .buttonStyle(FeedbackPressStyle())
    }
}

private struct FeedbackPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

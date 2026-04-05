import SwiftUI

struct FreeLimitGateView: View {
    let vm: ReviewSessionViewModel
    let onUpgrade: () -> Void
    let onViewSummary: () -> Void
    let onFinish: () -> Void

    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            LinearGradient.session.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Spacing.xxl)

                    ZStack {
                        Circle()
                            .fill(LinearGradient.streak.opacity(glowOpacity))
                            .frame(width: 160, height: 160)
                            .blur(radius: 50)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: glowOpacity
                            )

                        VStack(spacing: Spacing.sm) {
                            Text("✅")
                                .font(.system(size: 48))
                            Text("Done for the day")
                                .font(.lexisH1)
                                .foregroundColor(.moonPearl)
                            Text("Free plan · \(vm.freeCardLimit) cards per session")
                                .font(.lexisCaption)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                            Text("Upgrade to unlock unlimited reviews")
                                .font(.lexisCaption)
                                .foregroundColor(.amberGlow.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer().frame(height: Spacing.xxl)

                    GlassCard(padding: Spacing.lg) {
                        VStack(spacing: Spacing.md) {
                            HStack(alignment: .top) {
                                statRow(
                                    label: "New cards",
                                    value: "\(vm.sessionNewCardsRated)",
                                    color: .cobaltBlue
                                )
                                Spacer()
                                statRow(
                                    label: "Due reviews",
                                    value: "\(vm.sessionReviewCardsRated)",
                                    color: .skyBlue
                                )
                            }
                            .padding(.vertical, 4)

                            Text("Premium unlocks unlimited words each session and full packs.")
                                .font(.lexisCaption)
                                .foregroundColor(.textTertiary)
                                .multilineTextAlignment(.center)

                            Divider().background(Color.glassBorder)

                            Text("Want more? Unlock unlimited reviews and full word packs.")
                                .font(.lexisBodySm)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)

                    Spacer().frame(height: Spacing.xxl)

                    VStack(spacing: Spacing.md) {
                        Button {
                            Haptics.impact(.medium)
                            onUpgrade()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "crown.fill")
                                Text("Upgrade to Premium")
                            }
                        }
                        .primaryStyle()
                        .padding(.horizontal, Spacing.xl)

                        Button {
                            Haptics.impact(.light)
                            onViewSummary()
                        } label: {
                            Text("View session summary")
                        }
                        .ghostStyle(color: .cobaltBlue)

                        Button {
                            Haptics.impact(.light)
                            onFinish()
                        } label: {
                            Text("Back to Home")
                        }
                        .ghostStyle(color: .textSecondary)
                    }

                    Spacer().frame(height: 48)
                }
            }
        }
        .onAppear { glowOpacity = 0.55 }
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.lexisH2)
                .foregroundColor(color)
            Text(label)
                .font(.lexisCaption)
                .foregroundColor(.textTertiary)
        }
    }
}

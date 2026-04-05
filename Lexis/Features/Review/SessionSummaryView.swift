import SwiftUI

struct SessionSummaryView: View {
    let summary: SessionSummaryResponse
    let streak: StreakResponse
    /// Counts from this session’s ratings (not queue meta).
    let sessionNewCardsRated: Int
    let sessionReviewCardsRated: Int
    let onQuizMe: () -> Void
    let onDone: () -> Void
    var onUpgrade: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showCelebration: Bool = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var revealed: Bool = false

    private var isCompleted: Bool {
        summary.summary.cardsSeen > 0
    }

    var body: some View {
        ZStack {
            LinearGradient.session.ignoresSafeArea()

            if isCompleted {
                confettiLayer
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xxl) {
                    Spacer().frame(height: Spacing.xl)

                    // Streak day header
                    streakHeader

                    // Stats card
                    statsCard

                    // XP earned
                    xpBadge

                    // Milestones
                    if let milestones = summary.summary.milestonesUnlocked, !milestones.isEmpty {
                        milestonesSection(milestones)
                    }

                    // CTAs
                    ctaSection

                    Spacer().frame(height: 48)
                }
                .padding(.horizontal, Spacing.xl)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 20)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    revealed = true
                }
                if isCompleted && !reduceMotion {
                    launchConfetti()
                }
            }
        }
    }

    // MARK: - Streak Header

    private var streakHeader: some View {
        VStack(spacing: Spacing.md) {
            if streak.currentStreak > 0 {
                ZStack {
                    Circle()
                        .fill(LinearGradient.streak.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .blur(radius: 25)

                    VStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 38))
                        Text("Day \(streak.currentStreak)")
                            .font(.lexisDisplay3)
                            .foregroundStyle(LinearGradient.streak)
                    }
                }
            } else {
                Text("Session Complete")
                    .font(.lexisH1)
                    .foregroundColor(.moonPearl)
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        GlassCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.lg) {
                HStack {
                    summaryStatItem(
                        value: "\(summary.summary.cardsSeen)",
                        label: "This session",
                        accent: .moonPearl
                    )
                    Divider().background(Color.glassBorder).frame(height: 40)
                    summaryStatItem(
                        value: "\(sessionNewCardsRated)",
                        label: "New cards",
                        accent: .cobaltBlue
                    )
                    Divider().background(Color.glassBorder).frame(height: 40)
                    summaryStatItem(
                        value: "\(sessionReviewCardsRated)",
                        label: "Due reviews",
                        accent: .skyBlue
                    )
                }

                Text("New = first exposure · Due = words due for spaced review")
                    .font(.lexisCaption)
                    .foregroundColor(.textTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func summaryStatItem(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.lexisDisplay3)
                .foregroundColor(accent)
            Text(label)
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - XP Badge

    private var xpBadge: some View {
        let xp = summary.summary.xpEarned
        return HStack(spacing: Spacing.sm) {
            Text("⭐️")
                .font(.system(size: 20))
            Text(xp == 0 ? "0 XP" : "+\(xp) XP")
                .font(.lexisH3)
                .foregroundStyle(LinearGradient.streak)
            Text("earned")
                .font(.lexisBodySm)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
        .background(Color.amberGlow.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.amberGlow.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Milestones

    private func milestonesSection(_ milestones: [Milestone]) -> some View {
        VStack(spacing: Spacing.md) {
            ForEach(milestones) { milestone in
                HStack(spacing: Spacing.md) {
                    Text("🏆")
                        .font(.system(size: 22))
                    Text(milestone.message)
                        .font(.lexisBodyM)
                        .foregroundColor(.amberGlow)
                }
                .padding(Spacing.lg)
                .background(Color.amberGlow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.amberGlow.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - CTAs

    private var ctaSection: some View {
        VStack(spacing: Spacing.md) {
            Button {
                Haptics.impact(.medium)
                onQuizMe()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Quiz Me")
                }
            }
            .primaryStyle()

            if !AuthSession.shared.isProUser, let onUpgrade {
                Button {
                    Haptics.impact(.medium)
                    onUpgrade()
                } label: {
                    HStack(spacing: 4) {
                        Text("👑")
                        Text("Want more? Upgrade to Premium")
                            .font(.lexisBodySm)
                            .foregroundColor(.amberGlow)
                    }
                }
            }

            Button("Done", action: onDone)
                .ghostStyle(color: .textSecondary)
        }
    }

    // MARK: - Confetti

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var size: CGFloat
        var velocity: CGFloat
        var drift: CGFloat
    }

    private func launchConfetti() {
        confettiParticles = (0..<60).map { _ in
            ConfettiParticle(
                x: CGFloat.random(in: 0.1...0.9),
                y: -0.05,
                color: [Color.cobaltBlue, Color.skyBlue, Color.amberGlow, Color.jadeGreen, Color.coralRed][Int.random(in: 0...4)],
                size: CGFloat.random(in: 5...10),
                velocity: CGFloat.random(in: 0.3...0.8),
                drift: CGFloat.random(in: -0.2...0.2)
            )
        }
        showCelebration = true
    }

    private var confettiLayer: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for particle in confettiParticles {
                    let elapsed = t.truncatingRemainder(dividingBy: 3)
                    let x = (particle.x + particle.drift * elapsed * 0.1).truncatingRemainder(dividingBy: 1) * size.width
                    let y = (particle.y + particle.velocity * elapsed * 0.4).truncatingRemainder(dividingBy: 1.2) * size.height
                    if y < 0 || y > size.height { continue }
                    let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size * 0.6)
                    context.opacity = max(0, 1 - elapsed / 2.5)
                    context.fill(Path(ellipseIn: rect), with: .color(particle.color))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

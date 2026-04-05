import SwiftUI

struct ReviewCTACard: View {
    let phase: HomeReviewCTAPhase
    let onBegin: () -> Void
    var hasPausedSession: Bool = false
    var completedSessionToday: Bool = false
    var onRecap: (() -> Void)? = nil

    @State private var pulse = false

    var body: some View {
        GlassCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.md) {
                // Paused session takes top priority
                if hasPausedSession {
                    resumeContent
                    Button("Continue Review") {
                        Haptics.impact(.medium)
                        onBegin()
                    }
                    .primaryStyle()
                } else {
                    switch phase {
                    case .newUser(let hint):
                        newUserContent(hint: hint)
                        Button("Begin your journey") {
                            Haptics.impact(.medium)
                            onBegin()
                        }
                        .primaryStyle()

                    case .due(let count, let minutes):
                        dueContent(count: count, minutes: minutes)
                        Button("Begin Session") {
                            Haptics.impact(.medium)
                            onBegin()
                        }
                        .primaryStyle()

                    case .caughtUp:
                        caughtUpContent
                        if completedSessionToday, let onRecap {
                            Button("See Today's Words") {
                                Haptics.impact(.medium)
                                onRecap()
                            }
                            .primaryStyle()
                        } else {
                            VStack(spacing: Spacing.sm) {
                                Button("Start Practice") {
                                    Haptics.impact(.medium)
                                    onBegin()
                                }
                                .primaryStyle()
                                Text("Optional — no reviews due right now.")
                                    .font(.lexisCaption)
                                    .foregroundColor(.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .onAppear { pulse = phase.involvesDuePulse && !hasPausedSession }
        .onChange(of: phase) { _, p in pulse = p.involvesDuePulse && !hasPausedSession }
        .onChange(of: hasPausedSession) { _, v in pulse = phase.involvesDuePulse && !v }
    }

    // MARK: - Resume content

    private var resumeContent: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.amberGlow.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.amberGlow)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Resume your review")
                    .font(.lexisH2)
                    .foregroundColor(.moonPearl)
                Text("Pick up where you left off")
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - New user

    private func newUserContent(hint: Int) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(LinearGradient.hero.opacity(0.22))
                    .frame(width: 48, height: 48)
                Text("v")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient.hero)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Your library is ready")
                    .font(.lexisH2)
                    .foregroundColor(.moonPearl)
                if hint > 0 {
                    Text("\(hint) words waiting for you")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                } else {
                    Text("Start your first session — we'll pull words from your account.")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Due

    private func dueContent(count: Int, minutes: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(count) words due")
                    .font(.lexisH2)
                    .foregroundColor(.moonPearl)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                    Text("~\(minutes) min")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient.hero.opacity(0.25))
                    .frame(width: 44, height: 44)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                        value: pulse
                    )
                Circle()
                    .fill(LinearGradient.hero)
                    .frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Caught up

    private var caughtUpContent: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 28))
                .foregroundStyle(LinearGradient.hero)
            VStack(alignment: .leading, spacing: 4) {
                Text("All caught up!")
                    .font(.lexisH2)
                    .foregroundColor(.moonPearl)
                Text("No reviews due. Keep your streak by practising today.")
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Streak + progress stats (separate from session CTA card)

struct StreakProgressHeroCard: View {
    let streak: StreakResponse?
    let history: [String]
    let dueToday: Int
    let wordsNew: Int
    let wordsLearning: Int
    let wordsMastered: Int
    let retentionPct: Int
    let hasProgress: Bool

    @State private var flameScale: CGFloat = 1.0
    @State private var appeared = false

    private struct WordStatPillModel: Identifiable {
        let id: String
        let value: String
        let label: String
        let accent: Color
    }

    private var currentStreak: Int { streak?.currentStreak ?? 0 }
    private var longestStreak: Int { streak?.longestStreak ?? 0 }
    private var freezeCredits: Int { streak?.freezeCredits ?? 0 }

    private var todayIsActive: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return history.contains(fmt.string(from: Date()))
    }

    private var showRetention: Bool {
        retentionPct > 0 && (wordsMastered + wordsLearning + wordsNew) >= 3
    }

    /// Only non-zero counts from progress summary; retention only when `showRetention`.
    private var visibleWordStatPills: [WordStatPillModel] {
        var pills: [WordStatPillModel] = []
        if dueToday > 0 {
            pills.append(WordStatPillModel(id: "due", value: "\(dueToday)", label: "due today", accent: .dustGold))
        }
        if wordsNew > 0 {
            pills.append(WordStatPillModel(id: "new", value: "\(wordsNew)", label: "new", accent: .textTertiary))
        }
        if wordsLearning > 0 {
            pills.append(WordStatPillModel(id: "learning", value: "\(wordsLearning)", label: "learning", accent: .skyBlue))
        }
        if wordsMastered > 0 {
            pills.append(WordStatPillModel(id: "mastered", value: "\(wordsMastered)", label: "mastered", accent: .jadeGreen))
        }
        if showRetention {
            pills.append(WordStatPillModel(id: "retention", value: "\(retentionPct)%", label: "retention", accent: .navyBlue))
        }
        return pills
    }

    private var wordStatRows: [[WordStatPillModel]] {
        let pills = visibleWordStatPills
        guard !pills.isEmpty else { return [] }
        return stride(from: 0, to: pills.count, by: 3).map { i in
            Array(pills[i..<min(i + 3, pills.count)])
        }
    }

    var body: some View {
        GlassCard(padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack {
                    Text("Your progress")
                        .font(.lexisCaptionM)
                        .foregroundColor(.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                }

                streakBlock

                if hasProgress && !visibleWordStatPills.isEmpty {
                    Divider().background(Color.glassBorder)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Word counts")
                            .font(.lexisCaption)
                            .foregroundColor(.textSecondary)
                        statsRows
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 6)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .onAppear {
            if currentStreak > 0 { flameScale = 1.08 }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.06)) {
                appeared = true
            }
        }
    }

    private var streakBlock: some View {
        VStack(spacing: Spacing.md) {
            HStack(alignment: .center) {
                HStack(spacing: Spacing.sm) {
                    Text("🔥")
                        .font(.system(size: 26))
                        .scaleEffect(currentStreak > 0 ? flameScale : 1.0)
                        .opacity(currentStreak > 0 ? 1 : 0.4)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: flameScale
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        if currentStreak > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("\(currentStreak)")
                                        .font(.lexisDisplay3)
                                        .foregroundStyle(LinearGradient.streak)
                                    Text("day streak")
                                        .font(.lexisCaption)
                                        .foregroundColor(.textSecondary)
                                }
                                if longestStreak > currentStreak {
                                    Text("Best: \(longestStreak) days")
                                        .font(.lexisCaption)
                                        .foregroundColor(.textTertiary)
                                }
                            }
                        } else {
                            Text("No streak yet")
                                .font(.lexisH2)
                                .foregroundColor(.moonPearl)
                            Text("Complete a session to start your streak")
                                .font(.lexisCaption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                }

                Spacer()

                if todayIsActive && currentStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.jadeGreen)
                        Text("Today done")
                            .font(.lexisCaption)
                            .foregroundColor(.jadeGreen)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.jadeGreen.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            StreakDots(history: history, ringTodayWhenInactive: currentStreak == 0)

            if freezeCredits > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.skyBlue)
                    Text("\(freezeCredits) streak freeze\(freezeCredits == 1 ? "" : "s") left")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if currentStreak > 0 && !todayIsActive {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.amberGlow)
                    Text("Review today to keep your streak going")
                        .font(.lexisCaption)
                        .foregroundColor(.amberGlow)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.amberGlow.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Color.amberGlow.opacity(0.18), lineWidth: 1))
            }
        }
    }

    private var statsRows: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(Array(wordStatRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { idx, pill in
                        Group {
                            if idx > 0 { divider }
                            StatPill(value: pill.value, label: pill.label, accent: pill.accent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.glassBorder)
            .frame(width: 1, height: 36)
    }
}

private extension HomeReviewCTAPhase {
    var involvesDuePulse: Bool {
        if case .due(let c, _) = self { return c > 0 }
        return false
    }
}

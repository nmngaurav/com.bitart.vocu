import SwiftUI

/// Compact stats row when there is meaningful progress beyond a single “mastered” count.
struct TodayStatsCard: View {
    let hasProgress: Bool
    let wordsMasteredForRetentionGate: Int
    let wordsLearning: Int
    let retentionPct: Int
    let dueToday: Int

    private var showRetention: Bool {
        retentionPct > 0 && (wordsMasteredForRetentionGate + wordsLearning) >= 2
    }

    private var hasAnythingToShow: Bool {
        dueToday > 0 || wordsLearning > 0 || showRetention
    }

    var body: some View {
        if hasProgress && hasAnythingToShow {
            GlassCard(padding: Spacing.lg) {
                HStack(spacing: 0) {
                    if dueToday > 0 {
                        StatPill(value: "\(dueToday)", label: "due today", accent: .dustGold)
                            .frame(maxWidth: .infinity)
                    }

                    if wordsLearning > 0 {
                        if dueToday > 0 { divider }
                        StatPill(value: "\(wordsLearning)", label: "in progress", accent: .skyBlue)
                            .frame(maxWidth: .infinity)
                    }

                    if showRetention {
                        if dueToday > 0 || wordsLearning > 0 { divider }
                        StatPill(value: "\(retentionPct)%", label: "retention", accent: .cobaltBlue)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.glassBorder)
            .frame(width: 1, height: 36)
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let accent: Color

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(value)
                .font(.lexisH1)
                .foregroundColor(accent)
            Text(label)
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)
        }
    }
}

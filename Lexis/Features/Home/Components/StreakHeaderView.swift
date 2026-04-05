import SwiftUI

struct StreakHeaderView: View {
    let streak: StreakResponse?
    let history: [String]

    @State private var flameScale: CGFloat = 1.0

    private var currentStreak: Int { streak?.currentStreak ?? 0 }

    private var todayIsActive: Bool {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return history.contains(fmt.string(from: Date()))
    }

    var body: some View {
        GlassCard(padding: Spacing.lg) {
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
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text("\(currentStreak)")
                                        .font(.lexisDisplay3)
                                        .foregroundStyle(LinearGradient.streak)
                                    Text("day streak")
                                        .font(.lexisCaption)
                                        .foregroundColor(.textSecondary)
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
        .padding(.horizontal, Spacing.xl)
        .onAppear {
            if currentStreak > 0 { flameScale = 1.08 }
        }
    }
}

// MARK: - Streak Dots (last 7 days)

struct StreakDots: View {
    let history: [String]
    var ringTodayWhenInactive: Bool = false

    private var last7Days: [(date: String, active: Bool)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current
        let today = Date()
        return (0..<7).reversed().map { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return ("", false) }
            let str = fmt.string(from: date)
            return (str, history.contains(str))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(last7Days.enumerated()), id: \.offset) { i, day in
                let isToday = i == last7Days.count - 1
                VStack(spacing: 4) {
                    ZStack {
                        if day.active {
                            Circle()
                                .fill(AnyShapeStyle(LinearGradient.streak))
                                .frame(width: 28, height: 28)
                            Text("🔥").font(.system(size: 12))
                        } else if ringTodayWhenInactive && isToday {
                            Circle()
                                .strokeBorder(Color.cobaltBlue.opacity(0.9), lineWidth: 2)
                                .background(Circle().fill(Color.cobaltBlue.opacity(0.12)))
                                .frame(width: 28, height: 28)
                            Circle()
                                .fill(Color.moonPearl.opacity(0.35))
                                .frame(width: 8, height: 8)
                        } else {
                            Circle()
                                .fill(Color.textTertiary.opacity(0.3))
                                .frame(width: 28, height: 28)
                        }
                    }
                    let calendar = Calendar.current
                    let weekday = calendar.component(.weekday, from: Date()) - 1
                    let dayIndex = (weekday - (6 - i) + 7) % 7
                    Text(["S", "M", "T", "W", "T", "F", "S"][dayIndex])
                        .font(.lexisMonoSm)
                        .foregroundColor(isToday ? Color.cobaltBlue.opacity(0.9) : Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

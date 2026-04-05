import SwiftData
import SwiftUI

struct WordListView: View {
    @State private var vm = WordListViewModel()
    @State private var selectedSession: SessionHistoryItem? = nil

    private let todayKey: String
    @Query private var todayWords: [WordDayActivityRecord]

    init() {
        let key = TodayWordActivityWriter.dayKey()
        todayKey = key
        _todayWords = Query(
            filter: #Predicate<WordDayActivityRecord> { $0.dayKey == key },
            sort: \WordDayActivityRecord.lastUpdatedAt,
            order: .reverse
        )
    }

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()

            if vm.isLoading && vm.sessions.isEmpty {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .tint(.cobaltBlue)
                    Text("Loading sessions…")
                        .font(.lexisBodySm)
                        .foregroundColor(.textSecondary)
                }
            } else if let err = vm.errorMessage, vm.sessions.isEmpty {
                EmptyStateView(
                    icon: "📚",
                    title: "Couldn't load history",
                    subtitle: err,
                    actionTitle: "Try again",
                    action: { Task { await vm.load() } }
                )
                .padding(.horizontal, Spacing.xl)
            } else if vm.sessions.isEmpty, todayWords.isEmpty {
                EmptyStateView(
                    icon: "✨",
                    title: "No activity yet",
                    subtitle: "Complete a session — your reviewed words and session stats will appear here."
                )
                .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        if !todayWords.isEmpty {
                            todaySection
                        }
                        if !vm.sessions.isEmpty {
                            historyHeader
                            ForEach(vm.sessions) { item in
                                sessionRow(item)
                                    .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
                                    .onTapGesture {
                                        Haptics.impact(.light)
                                        selectedSession = item
                                    }
                            }
                        }
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.top, Spacing.lg)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $selectedSession) { session in
            SessionRecapView(session: session, onDismiss: { selectedSession = nil })
                .presentationBackground(Color.inkBlack)
        }
    }

    // MARK: - Today Section

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today · \(todayKeyDisplay)")
                    .font(.lexisDisplay3)
                    .foregroundColor(.moonPearl)
                Text("Words you interacted with today")
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
            }

            ForEach(todayWords, id: \.stableId) { row in
                TodayWordRow(row: row)
            }
        }
        .padding(.bottom, Spacing.sm)
    }

    private var todayKeyDisplay: String {
        let p = todayKey.split(separator: "-")
        guard p.count == 3,
              let y = Int(p[0]), let m = Int(p[1]), let d = Int(p[2]) else {
            return todayKey
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        guard let date = cal.date(from: DateComponents(year: y, month: m, day: d)) else {
            return todayKey
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    // MARK: - History Section

    private var historyHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Past Sessions")
                .font(.lexisDisplay3)
                .foregroundColor(.moonPearl)
            Text("Completed review runs with accuracy and duration.")
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)
        }
        .padding(.bottom, Spacing.md)
    }

    private func sessionRow(_ item: SessionHistoryItem) -> some View {
        GlassCard(padding: 0) {
            HStack(spacing: 0) {
                // Leading accent bar
                LinearGradient.hero
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                    .padding(.vertical, Spacing.lg)
                    .padding(.leading, Spacing.md)

                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(WordListViewModel.displayTitle(for: item))
                                .font(.lexisH3)
                                .foregroundColor(.moonPearl)
                                .lineLimit(2)
                            if let date = formattedDate(item.startedAt) {
                                Text(date)
                                    .font(.lexisCaption)
                                    .foregroundColor(.textTertiary)
                            }
                        }
                        Spacer(minLength: Spacing.sm)
                        // Accuracy badge
                        Text("\(item.accuracyPct)%")
                            .font(.lexisCaptionM)
                            .foregroundColor(accuracyColor(item.accuracyPct))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(accuracyColor(item.accuracyPct).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    summaryChips(item)

                    HStack(spacing: 0) {
                        metricColumn(
                            value: "\(item.cardsSeen)",
                            label: "Cards",
                            accent: .cobaltBlue
                        )
                        sessionMetricDivider
                        metricColumn(
                            value: "\(item.accuracyPct)%",
                            label: "Accuracy",
                            accent: accuracyColor(item.accuracyPct)
                        )
                        sessionMetricDivider
                        metricColumn(
                            value: formatDuration(item.durationSeconds),
                            label: "Time",
                            accent: .textSecondary
                        )
                    }
                    .padding(.vertical, Spacing.sm)
                    .background(Color.glassBorder.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                    // Recap CTA
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                        Text("View word recap")
                            .font(.lexisCaption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.cobaltBlue.opacity(0.75))
                }
                .padding(Spacing.lg)
            }
        }
    }

    private func accuracyColor(_ pct: Int) -> Color {
        if pct >= 80 { return .jadeGreen }
        if pct >= 50 { return .dustGold }
        return .coralRed
    }

    @ViewBuilder
    private func summaryChips(_ item: SessionHistoryItem) -> some View {
        let chips: [(String, Color)] = {
            var list: [(String, Color)] = []
            if item.accuracyPct >= 85 {
                list.append(("Strong round", .jadeGreen))
            } else if item.accuracyPct < 55, item.cardsSeen >= 5 {
                list.append(("Room to grow", .dustGold))
            }
            if item.durationSeconds >= 120 {
                list.append(("Deep focus", .cobaltBlue))
            }
            return list
        }()

        if !chips.isEmpty {
            SessionChipRow(chips: chips)
        }
    }

    private var sessionMetricDivider: some View {
        Rectangle()
            .fill(Color.glassBorderActive.opacity(0.5))
            .frame(width: 1)
            .frame(maxHeight: 40)
    }

    private func metricColumn(value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.lexisH3)
                .foregroundColor(accent)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            Text(label)
                .font(.lexisCaption)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: iso)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: iso)
        }
        guard let date else { return nil }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        if m == 0 { return "\(s)s" }
        return "\(m)m \(s)s"
    }
}

// MARK: - Today Word Row

private struct TodayWordRow: View {
    let row: WordDayActivityRecord

    var body: some View {
        GlassCard(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Thumbnail if available
                if let urlStr = row.imageUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill()
                        default:
                            Color.cobaltBlue.opacity(0.15)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.term)
                        .font(.lexisH3)
                        .foregroundColor(.moonPearl)
                        .lineLimit(1)
                    Text(sourceLine(for: row))
                        .font(.lexisCaption)
                        .foregroundColor(.textTertiary)
                }

                Spacer(minLength: Spacing.xs)

                if let r = row.ratingLabel, !r.isEmpty {
                    Text(r)
                        .font(.lexisCaptionM)
                        .foregroundColor(ratingColor(r))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ratingColor(r).opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(ratingColor(r).opacity(0.25), lineWidth: 1))
                }
            }
        }
    }

    private func sourceLine(for row: WordDayActivityRecord) -> String {
        let src = WordActivitySource(rawValue: row.sourceRaw) ?? .library
        return src == .library ? "Library" : "Review session"
    }

    private func ratingColor(_ label: String) -> Color {
        switch label {
        case "Still Learning": return .coralRed
        case "Almost":         return .dustGold
        case "Nailed It!":     return .jadeGreen
        default:               return .cobaltBlue
        }
    }
}

// MARK: - Session summary chips

private struct SessionChipRow: View {
    let chips: [(String, Color)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                sessionChip(chip.0, chip.1)
            }
        }
    }

    private func sessionChip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.lexisCaptionM)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.5))
    }
}

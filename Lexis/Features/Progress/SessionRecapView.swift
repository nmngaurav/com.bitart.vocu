import SwiftData
import SwiftUI

// MARK: - Session Recap (flexible: from dayKey OR SessionHistoryItem)

struct SessionRecapView: View {
    let displayTitle: String
    let session: SessionHistoryItem?
    let onDismiss: () -> Void

    private let dayKey: String

    @Query private var activityRecords: [WordDayActivityRecord]
    @State private var currentPage = 0

    // Init from HomeView "Today's Words" button
    init(dayKey: String, title: String = "Today's Words", onDismiss: @escaping () -> Void) {
        self.dayKey = dayKey
        self.displayTitle = title
        self.session = nil
        self.onDismiss = onDismiss
        _activityRecords = Query(
            filter: #Predicate<WordDayActivityRecord> { $0.dayKey == dayKey },
            sort: \WordDayActivityRecord.lastUpdatedAt,
            order: .forward
        )
    }

    // Init from history / session item
    init(session: SessionHistoryItem, onDismiss: @escaping () -> Void) {
        self.session = session
        self.displayTitle = "Session Recap"
        self.onDismiss = onDismiss

        let key = SessionRecapView.dayKeyFromISO(session.startedAt)
        self.dayKey = key
        _activityRecords = Query(
            filter: #Predicate<WordDayActivityRecord> { $0.dayKey == key },
            sort: \WordDayActivityRecord.lastUpdatedAt,
            order: .forward
        )
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = max(geo.safeAreaInsets.top, 44)
            let headerH = safeTop + 8 + 52 + 12
            let tabH = max(220, geo.size.height - headerH)
            // Card has horizontal margins so it floats with ghost stack visible
            let hPad: CGFloat = 16
            let cardW = geo.size.width - hPad * 2
            let cardH = tabH - 56 // page dots + breathing room

            ZStack(alignment: .top) {
                LinearGradient.session.ignoresSafeArea()

                VStack(spacing: 0) {
                    recapHeaderBar(safeTop: safeTop)
                        .frame(height: headerH)

                    if activityRecords.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, Spacing.xl)
                    } else {
                        VStack(spacing: Spacing.md) {
                            RecapDeckPager(
                                records: activityRecords,
                                cardWidth: cardW,
                                cardHeight: cardH,
                                pageIndex: $currentPage
                            )
                            .frame(height: cardH)
                            .padding(.horizontal, hPad)

                            recapPageDots(count: activityRecords.count, current: currentPage)
                                .padding(.bottom, Spacing.sm)
                        }
                        .frame(height: tabH)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func recapHeaderBar(safeTop: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.lexisH3)
                    .foregroundColor(.moonPearl)
                HStack(spacing: Spacing.sm) {
                    Text("\(activityRecords.count) words")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                    if let s = session, s.accuracyPct > 0 {
                        Text("·")
                            .foregroundColor(.textTertiary)
                        Text("\(s.accuracyPct)% accuracy")
                            .font(.lexisCaptionM)
                            .foregroundColor(accuracyColor(s.accuracyPct))
                    }
                }
            }

            Spacer()

            Button {
                Haptics.impact(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.glassBorder, lineWidth: 1))
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, safeTop + 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.sessionGradientTop.opacity(0.5), Color.clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(LinearGradient.hero.opacity(0.8))
            VStack(spacing: Spacing.sm) {
                Text("Nothing reviewed yet")
                    .font(.lexisH3)
                    .foregroundColor(.moonPearl)
                Text("Words you review today will appear here.")
                    .font(.lexisBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.xxxl)
    }

    private func accuracyColor(_ pct: Int) -> Color {
        pct >= 80 ? .jadeGreen : pct >= 50 ? .dustGold : .coralRed
    }

    static func dayKeyFromISO(_ isoString: String?) -> String {
        guard let iso = isoString, !iso.isEmpty else { return TodayWordActivityWriter.dayKey() }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: iso)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: iso)
        }
        guard let date else { return TodayWordActivityWriter.dayKey() }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else {
            return TodayWordActivityWriter.dayKey()
        }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - Deck pager (drag follows finger)

private struct RecapDeckPager: View {
    let records: [WordDayActivityRecord]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var pageIndex: Int

    @State private var topFlipped = false
    @State private var dragX: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the user is dragging toward the next card (0…1); drives back-card scale / lift.
    private var nextPeekProgress: CGFloat {
        guard !reduceMotion, dragX < 0, pageIndex + 1 < records.count else { return 0 }
        let d = -dragX
        let denom = max(120, cardWidth * 0.42)
        return min(1, d / denom)
    }

    private func rubberBand(_ raw: CGFloat) -> CGFloat {
        let atEnd = pageIndex >= records.count - 1
        let atStart = pageIndex <= 0
        // Softer edge resistance so the deck follows the finger more naturally.
        if raw < 0, atEnd { return raw * 0.48 }
        if raw > 0, atStart { return raw * 0.48 }
        return raw
    }

    var body: some View {
        ZStack {
            if pageIndex + 1 < records.count {
                let p = nextPeekProgress
                let backScale = 0.93 + 0.07 * p
                let backY = 18 - 10 * p
                let backRot = 2 - 1.2 * p
                RecapFlipCard(
                    isFlipped: .constant(false),
                    record: records[pageIndex + 1],
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
                .scaleEffect(backScale)
                .offset(x: 5 + 8 * p, y: backY)
                .rotationEffect(.degrees(backRot))
                .allowsHitTesting(false)
            }

            if records.indices.contains(pageIndex) {
                let dragNorm = abs(dragX) / max(180, cardWidth * 0.52)
                let topScale = reduceMotion ? 1 : 1 - 0.014 * min(1, dragNorm)
                RecapFlipCard(
                    isFlipped: $topFlipped,
                    record: records[pageIndex],
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )
                .scaleEffect(topScale)
                .offset(x: dragX)
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragX) / 34))
                .shadow(
                    color: Color.black.opacity(0.10 + min(0.16, Double(abs(dragX) / CGFloat(520)))),
                    radius: CGFloat(16) + abs(dragX) / CGFloat(90),
                    x: dragX * CGFloat(0.038),
                    y: CGFloat(11)
                )
                .compositingGroup()
                .simultaneousGesture(pagingDrag)
            }
        }
        .onChange(of: pageIndex) { _, _ in
            topFlipped = false
            dragX = 0
        }
    }

    private var pagingDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard !topFlipped else { return }
                let tx = value.translation.width
                let ty = value.translation.height
                if abs(ty) > abs(tx) * 1.15 && abs(tx) < 24 { return }
                dragX = rubberBand(tx)
            }
            .onEnded { value in
                guard !topFlipped else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { dragX = 0 }
                    return
                }
                let w = value.translation.width
                let vx = value.velocity.width
                let distThreshold = min(72, cardWidth * 0.20)
                let velCommit: CGFloat = 380

                let commitNext = w < -distThreshold || (w < -28 && vx < -velCommit)
                let commitPrev = w > distThreshold || (w > 28 && vx > velCommit)

                if commitNext, pageIndex < records.count - 1 {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.91)) {
                        pageIndex += 1
                    }
                    dragX = 0
                } else if commitPrev, pageIndex > 0 {
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.91)) {
                        pageIndex -= 1
                    }
                    dragX = 0
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) { dragX = 0 }
                }
            }
    }
}

private func recapPageDots(count: Int, current: Int) -> some View {
    HStack(spacing: 7) {
        ForEach(0..<count, id: \.self) { i in
            Capsule()
                .fill(i == current ? Color.moonPearl : Color.textTertiary.opacity(0.35))
                .frame(width: i == current ? 22 : 7, height: 7)
                .animation(.spring(response: 0.35, dampingFraction: 0.78), value: current)
        }
    }
}

// MARK: - Recap Flip Card (Tinder-style with full-screen reveal)

private struct RecapFlipCard: View {
    @Binding var isFlipped: Bool
    let record: WordDayActivityRecord
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @State private var flipRotation: Double = 0
    @State private var imageCache: UIImage?
    @State private var imageLoadFailed = false
    @State private var showTapHint = true

    private var viewport: CGSize { CGSize(width: cardWidth, height: cardHeight) }

    var body: some View {
        ZStack(alignment: .top) {
            // Ghost card 2 — furthest back (stronger deck read in light mode)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surfaceCard.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.glassBorder.opacity(0.4), lineWidth: 1)
                )
                .frame(width: cardWidth - 24, height: cardHeight - 20)
                .offset(x: 4, y: 20)
                .rotationEffect(.degrees(-1.4))
                .shadow(color: Color.black.opacity(0.08), radius: 20, y: 8)

            // Ghost card 1 — middle
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.surfaceCard.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.glassBorderActive.opacity(0.5), lineWidth: 1)
                )
                .frame(width: cardWidth - 12, height: cardHeight - 12)
                .offset(x: 2, y: 10)
                .rotationEffect(.degrees(0.8))
                .shadow(color: Color.black.opacity(0.12), radius: 22, y: 10)

            // Main card (flippable)
            ZStack {
                frontFace
                    .rotation3DEffect(.degrees(flipRotation), axis: (0, 1, 0), perspective: 0.08)
                    .opacity(flipRotation < 90 ? 1 : 0)

                backFace
                    .rotation3DEffect(.degrees(flipRotation + 180), axis: (0, 1, 0), perspective: 0.08)
                    .opacity(flipRotation >= 90 ? 1 : 0)
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.24), radius: 20, x: 0, y: 10)
        }
        .onChange(of: isFlipped) { _, flipped in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                flipRotation = flipped ? 180 : 0
            }
        }
        .task(id: record.stableId) { await loadImage() }
        .onAppear { scheduleTapHintDismissal() }
    }

    private func scheduleTapHintDismissal() {
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.7)) { showTapHint = false }
            }
        }
    }

    // MARK: - Front (clean full-bleed image — no word/badge overlay)

    private var frontFace: some View {
        ZStack {
            if let ui = imageCache {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
            } else if imageLoadFailed {
                placeholderView
            } else {
                ZStack {
                    placeholderView
                    ProgressView().tint(.textTertiary)
                }
            }

            // Subtle bottom vignette
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.inkBlack.opacity(0.38)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: cardHeight * 0.14)
            }
            .allowsHitTesting(false)

            // Tap hint pill
            if showTapHint {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Tap for details")
                            .font(.lexisCaptionM)
                    }
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .padding(.bottom, 22)
                    .transition(.opacity)
                }
                .allowsHitTesting(false)
            }
        }
        .background(Color.deepNavy)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            isFlipped.toggle()
        }
    }

    // MARK: - Back (full-screen atmospheric reveal — same as review session)

    private var backFace: some View {
        ZStack {
            Color.inkBlack
            RadialGradient(
                colors: [
                    Color.cobaltBlue.opacity(0.20),
                    Color.inkBlack.opacity(0.94),
                    Color.inkBlack
                ],
                center: .topLeading,
                startRadius: 60,
                endRadius: 520
            )
            LinearGradient.session.opacity(0.18)

            RecapRevealContentView(
                record: record,
                onTap: {
                    Haptics.impact(.light)
                    isFlipped.toggle()
                }
            )
        }
        .contentShape(Rectangle())
    }

    // MARK: - Placeholder & image loader

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.navyBlue.opacity(0.55), Color.cobaltBlue.opacity(0.32)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Text(String(record.term.prefix(1).uppercased()))
                .font(.system(size: min(112, cardWidth * 0.28), weight: .black))
                .foregroundColor(.white.opacity(0.07))
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private func loadImage() async {
        imageCache = nil
        imageLoadFailed = false
        guard let s = record.imageUrl, let url = URL(string: s) else { return }
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                await MainActor.run { imageLoadFailed = true }
                return
            }
            if let ui = UIImage(data: data) {
                await MainActor.run { imageCache = ui }
            } else {
                await MainActor.run { imageLoadFailed = true }
            }
        } catch {
            await MainActor.run { imageLoadFailed = true }
        }
    }
}

// MARK: - Recap Reveal Content (word-lift animation for WordDayActivityRecord)

private struct RecapRevealContentView: View {
    let record: WordDayActivityRecord
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wordLifted = false
    @State private var defVisible = false
    @State private var exVisible = false
    @State private var ratingVisible = false
    @State private var ratingPop = false
    @State private var termBreath: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let liftY: CGFloat = reduceMotion ? 0 : (wordLifted ? -38 : 0)

            ZStack {
                recapRevealAmbientLayer(size: geo.size)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(minHeight: max(0, h * 0.30 - 24), maxHeight: h * 0.42)

                    wordBlock
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .offset(y: liftY)
                        .animation(
                            reduceMotion ? .default
                                : .spring(response: 0.52, dampingFraction: 0.82),
                            value: wordLifted
                        )

                    Spacer().frame(height: Spacing.lg)

                    infoBlock
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: max(Spacing.lg, h * 0.10))
                }
                .padding(.horizontal, Spacing.xl)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            runRevealSequence()
            startTermBreathIfNeeded()
        }
        .onChange(of: record.stableId) { _, _ in
            resetRevealState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                runRevealSequence()
                startTermBreathIfNeeded()
            }
        }
    }

    private func resetRevealState() {
        wordLifted = false
        defVisible = false
        exVisible = false
        ratingVisible = false
        ratingPop = false
        termBreath = 1
    }

    private func runRevealSequence() {
        if reduceMotion {
            wordLifted = true
            defVisible = true
            exVisible = true
            ratingVisible = true
            ratingPop = true
            return
        }
        withAnimation(.spring(response: 0.50, dampingFraction: 0.82)) {
            wordLifted = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                defVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
                exVisible = true
            }
        }
        let hasRating = !(record.ratingLabel ?? "").isEmpty
        if hasRating {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
                withAnimation(.spring(response: 0.40, dampingFraction: 0.78)) {
                    ratingVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.68)) {
                    ratingPop = true
                }
            }
        }
    }

    private func startTermBreathIfNeeded() {
        guard !reduceMotion else { return }
        termBreath = 1
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            termBreath = 1.022
        }
    }

    @ViewBuilder
    private func recapRevealAmbientLayer(size: CGSize) -> some View {
        if reduceMotion {
            RadialGradient(
                colors: [
                    Color.cobaltBlue.opacity(0.14),
                    Color.inkBlack.opacity(0.92),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: min(size.width, size.height) * 0.95
            )
            .allowsHitTesting(false)
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(t * 0.55)
                let cx = 0.12 + 0.06 * sin(t * 0.31)
                let cy = 0.08 + 0.05 * cos(t * 0.27)
                RadialGradient(
                    colors: [
                        Color.cobaltBlue.opacity(0.10 + 0.14 * pulse),
                        Color.jadeGreen.opacity(0.03 + 0.05 * (1 - pulse)),
                        Color.clear
                    ],
                    center: UnitPoint(x: cx, y: cy),
                    startRadius: 28,
                    endRadius: max(size.width, size.height) * 0.72
                )
                .allowsHitTesting(false)
            }
        }
    }

    private var wordBlock: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            if let pos = record.partOfSpeechText, !pos.isEmpty {
                Text(pos)
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.glassBorder.opacity(0.8))
                    .clipShape(Capsule())
            }

            Text(record.term)
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundColor(.moonPearl)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .scaleEffect(termBreath)
                .shadow(color: Color.cobaltBlue.opacity(0.22), radius: 12, y: 4)

            if let ph = record.phoneticText, !ph.isEmpty {
                Text(ph)
                    .font(.lexisMono)
                    .foregroundColor(.cobaltBlue.opacity(0.9))
            }

            AudioChip(audioURLString: record.audioUrlString ?? "", fallbackWord: record.term)
        }
        .multilineTextAlignment(.center)
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Rectangle()
                .fill(LinearGradient.hero)
                .frame(height: 1)
                .opacity(defVisible ? 0.35 : 0)
                .animation(.easeOut(duration: 0.35), value: defVisible)

            if let def = record.definitionText, !def.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("DEFINITION")
                        .font(.lexisMonoSm)
                        .foregroundColor(.textTertiary)
                        .tracking(1.2)
                    Text(def)
                        .font(.lexisH3)
                        .foregroundColor(.moonPearl)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(defVisible ? 1 : 0)
                .offset(y: defVisible ? 0 : 14)
                .animation(.spring(response: 0.48, dampingFraction: 0.86), value: defVisible)
            }

            if let ex = record.exampleText, !ex.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("EXAMPLE")
                        .font(.lexisMonoSm)
                        .foregroundColor(.textTertiary)
                        .tracking(1.2)
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        Rectangle()
                            .fill(LinearGradient.hero)
                            .frame(width: 3, height: 44)
                            .clipShape(Capsule())
                        Text("\u{201C}\(ex)\u{201D}")
                            .font(.lexisBody)
                            .italic()
                            .foregroundColor(.textSecondary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .opacity(exVisible ? 1 : 0)
                .offset(y: exVisible ? 0 : 16)
                .animation(.spring(response: 0.48, dampingFraction: 0.86), value: exVisible)
            }

            if let label = record.ratingLabel, !label.isEmpty {
                let color = CardRating.accentColor(forLabel: label)
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("YOUR RATING")
                        .font(.lexisMonoSm)
                        .foregroundColor(.textTertiary)
                        .tracking(1.2)
                    Text(label)
                        .font(.lexisCaptionM)
                        .foregroundColor(color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.16))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(color.opacity(0.42), lineWidth: 1))
                        .shadow(color: color.opacity(ratingPop ? 0.35 : 0), radius: ratingPop ? 10 : 0, y: 4)
                        .scaleEffect(ratingPop ? 1 : 0.88)
                }
                .opacity(ratingVisible ? 1 : 0)
                .offset(y: ratingVisible ? 0 : 10)
                .animation(.spring(response: 0.42, dampingFraction: 0.82), value: ratingVisible)
                .animation(.spring(response: 0.46, dampingFraction: 0.68), value: ratingPop)
            }
        }
    }
}

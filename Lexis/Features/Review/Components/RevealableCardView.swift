import SwiftUI
import UIKit

/// Shared backdrop for the flipped definition face and the feedback rating step (visual continuity).
struct ReviewSessionCardAtmosphere: View {
    var body: some View {
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
        }
    }
}

/// Shared capsule for review-flow hints (consistent look flip ↔ feedback).
struct ReviewSessionHintCapsule: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.cobaltBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lexisCaptionM)
                    .foregroundColor(.moonPearl)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.lexisCaption)
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(Color.glassBorder.opacity(0.88), lineWidth: 1)
        )
    }
}

private enum RevealableCardHintKeys {
    static let swipeToRateHintShown = "vocuSwipeToRateHintShown"
}

/// Word card: front = full-bleed image; back = bottom-sheet info overlay atop dimmed image.
/// Tap to flip either face.
struct RevealableCardView: View {
    let card: ReviewQueueCard
    let isRevealed: Bool
    let viewport: CGSize
    let onToggleReveal: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var imageCache: UIImage?
    @State private var imageLoadFailed = false
    @State private var flipRotation: Double = 0
    @State private var kenBurnsPhase = false
    @State private var showTapHint = true
    @State private var showSwipeToRateHint = false
    @State private var swipeHintOpacity: Double = 0

    var body: some View {
        ZStack {
            cardFrontFace
                .rotation3DEffect(.degrees(flipRotation), axis: (0, 1, 0), perspective: 0.08)
                .opacity(flipRotation < 90 ? 1 : 0)

            cardBackFace
                .rotation3DEffect(.degrees(flipRotation + 180), axis: (0, 1, 0), perspective: 0.08)
                .opacity(flipRotation >= 90 ? 1 : 0)
        }
        .frame(width: viewport.width, height: viewport.height)
        .onChange(of: isRevealed) { _, revealed in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.06)) {
                flipRotation = revealed ? 180 : 0
            }
            if revealed {
                scheduleSwipeToRateHintIfNeeded()
            } else {
                showSwipeToRateHint = false
                swipeHintOpacity = 0
            }
        }
        .onChange(of: card.wordId) { _, _ in
            flipRotation = isRevealed ? 180 : 0
            kenBurnsPhase = false
            showTapHint = true
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { kenBurnsPhase = true }
            }
            scheduleTapHintDismissal()
        }
        .onAppear {
            flipRotation = isRevealed ? 180 : 0
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { kenBurnsPhase = true }
            }
            scheduleTapHintDismissal()
            if isRevealed {
                scheduleSwipeToRateHintIfNeeded()
            }
        }
        .task(id: card.wordId) { await loadImageIfNeeded() }
    }

    private func scheduleTapHintDismissal() {
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.7)) { showTapHint = false }
            }
        }
    }

    private func scheduleSwipeToRateHintIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: RevealableCardHintKeys.swipeToRateHintShown) else { return }
        if reduceMotion {
            showSwipeToRateHint = true
            swipeHintOpacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                showSwipeToRateHint = false
                swipeHintOpacity = 0
                UserDefaults.standard.set(true, forKey: RevealableCardHintKeys.swipeToRateHintShown)
            }
            return
        }
        showSwipeToRateHint = true
        swipeHintOpacity = 0
        withAnimation(.easeOut(duration: 0.38)) { swipeHintOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.easeOut(duration: 0.48)) { swipeHintOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
                showSwipeToRateHint = false
                UserDefaults.standard.set(true, forKey: RevealableCardHintKeys.swipeToRateHintShown)
            }
        }
    }

    // MARK: - Front (full-bleed image)

    private var cardFrontFace: some View {
        ZStack {
            LexisBoundedImageView(
                uiImage: imageCache,
                loadFailed: imageLoadFailed,
                initialLetter: String(card.word.term.prefix(1).uppercased()),
                viewport: viewport,
                kenBurnsActive: kenBurnsPhase,
                reduceMotion: reduceMotion
            )

            // Subtle bottom vignette
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.inkBlack.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(80, viewport.height * 0.14))
            }
            .allowsHitTesting(false)

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
        .frame(width: viewport.width, height: viewport.height)
        .background(Color.deepNavy)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            onToggleReveal()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.word.term), image card. Tap to show definition and details")
    }

    // MARK: - Back (full-screen info card — premium reveal)

    private var cardBackFace: some View {
        ZStack {
            ReviewSessionCardAtmosphere()

            CardRevealContentView(
                card: card,
                onTap: {
                    Haptics.impact(.light)
                    onToggleReveal()
                },
                reduceMotion: reduceMotion
            )

            if showSwipeToRateHint {
                VStack {
                    Spacer()
                    HStack {
                        ReviewSessionHintCapsule(
                            systemImage: "arrow.left.circle.fill",
                            title: "Swipe left to rate",
                            subtitle: "When you’re done reading"
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
                .opacity(swipeHintOpacity)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityHint(
            isRevealed
                ? "When finished reading, swipe the card left to rate. Tap to return to the image."
                : ""
        )
    }

    // MARK: - Image loader

    private func loadImageIfNeeded() async {
        await MainActor.run {
            imageCache = nil
            imageLoadFailed = false
        }
        guard let s = card.word.primaryImageUrl else { return }

        if let localImage = await Task.detached(priority: .userInitiated, operation: { UIImage(named: s) }).value {
            await MainActor.run {
                imageCache = localImage
            }
            return
        }

        guard let url = URL(string: s) else { return }

        if let cached = await ImagePrefetcher.shared.cachedData(for: s) {
            let ui = await Task.detached(priority: .userInitiated) { UIImage(data: cached) }.value
            await MainActor.run {
                if let ui {
                    imageCache = ui
                } else {
                    imageLoadFailed = true
                }
            }
            return
        }

        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                await MainActor.run { imageLoadFailed = true }
                return
            }
            await ImagePrefetcher.shared.storeFromNetwork(urlString: s, data: data)
            let ui = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
            await MainActor.run {
                if let ui {
                    imageCache = ui
                } else {
                    imageLoadFailed = true
                }
            }
        } catch {
            await MainActor.run { imageLoadFailed = true }
        }
    }
}

// MARK: - Full-Screen Reveal Content (word-lift animation)

/// Reusable content view for the "back face" of a flip card.
/// Displays word centered, then lifts up as definition/info fades in.
struct CardRevealContentView: View {
    let card: ReviewQueueCard
    let onTap: () -> Void
    var reduceMotion: Bool = false
    var feedbackLabel: String? = nil

    @State private var termHeroVisible = false
    @State private var wordMetaVisible = false
    @State private var defVisible = false
    @State private var exVisible = false
    @State private var repVisible = false
    @State private var feedbackVisible = false
    @State private var termBreath: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let liftY: CGFloat = reduceMotion ? 0 : (termHeroVisible ? -28 : 0)

            ZStack {
                revealAmbientLayer(size: geo.size)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer()
                        .frame(minHeight: max(0, h * 0.28 - 20), maxHeight: h * 0.40)

                    wordHeroBlock
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .offset(y: liftY)
                        .scaleEffect(termBreath)
                        .opacity(termHeroVisible ? 1 : 0)
                        .offset(y: termHeroVisible ? 0 : 18)
                        .animation(
                            reduceMotion ? .default : .spring(response: 0.55, dampingFraction: 0.84),
                            value: termHeroVisible
                        )
                        .animation(
                            reduceMotion ? .default : .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                            value: termBreath
                        )

                    wordMetaRow
                        .padding(.top, Spacing.md)
                        .opacity(wordMetaVisible ? 1 : 0)
                        .offset(y: wordMetaVisible ? 0 : 10)
                        .animation(
                            reduceMotion ? .default : .spring(response: 0.48, dampingFraction: 0.86),
                            value: wordMetaVisible
                        )

                    Spacer().frame(height: Spacing.lg)

                    detailsBlock
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: max(Spacing.lg, h * 0.10))
                }
                .padding(.horizontal, Spacing.xl)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear { runRevealSequence() }
        .onChange(of: card.wordId) { _, _ in
            resetRevealState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                runRevealSequence()
            }
        }
        .onChange(of: termHeroVisible) { _, visible in
            guard visible, !reduceMotion else { return }
            termBreath = 1
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                termBreath = 1.018
            }
        }
    }

    @ViewBuilder
    private func revealAmbientLayer(size: CGSize) -> some View {
        if reduceMotion {
            RadialGradient(
                colors: [
                    Color.cobaltBlue.opacity(0.12),
                    Color.inkBlack.opacity(0.94),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: min(size.width, size.height) * 0.9
            )
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(t * 0.5)
                RadialGradient(
                    colors: [
                        Color.cobaltBlue.opacity(0.08 + 0.10 * pulse),
                        Color.inkBlack.opacity(0.94),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.12 + 0.04 * sin(t * 0.28), y: 0.1 + 0.03 * cos(t * 0.31)),
                    startRadius: 50,
                    endRadius: max(size.width, size.height) * 0.65
                )
            }
        }
    }

    private var wordHeroBlock: some View {
        Text(card.word.term)
            .font(.system(size: 44, weight: .black, design: .rounded))
            .foregroundColor(.moonPearl)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.62)
            .shadow(color: Color.cobaltBlue.opacity(0.2), radius: 14, y: 4)
    }

    private var wordMetaRow: some View {
        VStack(alignment: .center, spacing: Spacing.sm) {
            if let pos = card.word.partOfSpeech {
                Text(pos)
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(Color.glassBorder.opacity(0.8))
                    .clipShape(Capsule())
            }

            if let ph = card.word.phonetic {
                Text(ph)
                    .font(.lexisMono)
                    .foregroundColor(.cobaltBlue.opacity(0.9))
            }

            AudioChip(audioURLString: card.word.audioUrl ?? "", fallbackWord: card.word.term)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Rectangle()
                .fill(LinearGradient.hero)
                .frame(height: 1)
                .opacity(defVisible ? 0.35 : 0)
                .animation(.easeOut(duration: 0.35), value: defVisible)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("DEFINITION")
                    .font(.lexisMonoSm)
                    .foregroundColor(.textTertiary)
                    .tracking(1.2)
                Text(card.word.definition)
                    .font(.lexisH3)
                    .foregroundColor(.moonPearl)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(defVisible ? 1 : 0)
            .offset(y: defVisible ? 0 : 14)
            .animation(
                reduceMotion ? .default : .spring(response: 0.50, dampingFraction: 0.86),
                value: defVisible
            )

            if let ex = card.word.example, !ex.isEmpty {
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
                .animation(
                    reduceMotion ? .default : .spring(response: 0.50, dampingFraction: 0.86),
                    value: exVisible
                )
            }

            if card.progress.repetitionCount > 0 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.counterclockwise.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.skyBlue)
                    Text("Seen \(card.progress.repetitionCount)×")
                        .font(.lexisCaption)
                        .foregroundColor(.skyBlue)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.skyBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(Color.skyBlue.opacity(0.18), lineWidth: 1))
                .opacity(repVisible ? 1 : 0)
                .offset(y: repVisible ? 0 : 12)
                .animation(
                    reduceMotion ? .default : .spring(response: 0.48, dampingFraction: 0.86),
                    value: repVisible
                )
            }

            if let label = feedbackLabel, !label.isEmpty {
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
                        .background(color.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
                }
                .opacity(feedbackVisible ? 1 : 0)
                .offset(y: feedbackVisible ? 0 : 10)
                .animation(
                    reduceMotion ? .default : .spring(response: 0.46, dampingFraction: 0.84),
                    value: feedbackVisible
                )
            }
        }
    }

    private func resetRevealState() {
        termHeroVisible = false
        wordMetaVisible = false
        defVisible = false
        exVisible = false
        repVisible = false
        feedbackVisible = false
        termBreath = 1
    }

    private func runRevealSequence() {
        if reduceMotion {
            termHeroVisible = true
            wordMetaVisible = true
            defVisible = true
            exVisible = true
            repVisible = true
            feedbackVisible = true
            return
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
            termHeroVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                wordMetaVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
                defVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
                exVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.88) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                repVisible = true
            }
        }
        let hasFeedback = !(feedbackLabel ?? "").isEmpty
        if hasFeedback {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.02) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.84)) {
                    feedbackVisible = true
                }
            }
        }
    }
}

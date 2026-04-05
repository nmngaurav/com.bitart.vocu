import SwiftData
import SwiftUI
import UIKit

struct ReviewSessionView: View {
    let onDismiss: () -> Void

    @State private var vm = ReviewSessionViewModel()
    @State private var cardPhase: CardPhase = .word
    @Environment(\.modelContext) private var modelContext
    @State private var showSubscription = false
    @State private var audioFallbackToast: String?

    private enum CardPhase: Equatable { case word, feedback }

    var body: some View {
        ZStack {
            ReviewAmbientBackground()

            switch vm.state {
            case .loading:
                loadingView

            case .active:
                activeSessionStack

            case .completing:
                ZStack {
                    ReviewAmbientBackground()
                    ProgressView()
                        .tint(.moonPearl)
                        .scaleEffect(1.4)
                }

            case .freeLimitHit:
                FreeLimitGateView(
                    vm: vm,
                    onUpgrade: { showSubscription = true },
                    onViewSummary: { vm.promoteFreeLimitToComplete() },
                    onFinish: onDismiss
                )

            case .complete(let summary, let streak):
                SessionSummaryView(
                    summary: summary,
                    streak: streak,
                    sessionNewCardsRated: vm.sessionNewCardsRated,
                    sessionReviewCardsRated: vm.sessionReviewCardsRated,
                    onQuizMe: {
                        cardPhase = .word
                        Task { await vm.startSession() }
                    },
                    onDone: onDismiss,
                    onUpgrade: { showSubscription = true }
                )

            case .error(let msg):
                errorView(msg)

            case .dismissedWithoutSummary:
                Color.clear
            }
        }
        .onAppear {
            vm.onRatedCard = { card, rating in
                TodayWordActivityWriter.recordReview(
                    modelContext: modelContext,
                    card: card,
                    rating: rating
                )
                try? modelContext.save()
            }
        }
        .task { await vm.startSession() }
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .onChange(of: showSubscription) { _, isShowing in
            if !isShowing && AuthSession.shared.isProUser {
                cardPhase = .word
                Task { await vm.startSession() }
            }
        }
        .onChange(of: vm.state) { _, newState in
            if case .dismissedWithoutSummary = newState {
                AudioPlaybackService.shared.stop()
                onDismiss()
                return
            }
            if case .active = newState { return }
            AudioPlaybackService.shared.stop()
        }
        .onChange(of: vm.currentIndex) { _, _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                cardPhase = .word
            }
            AudioPlaybackService.shared.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vocuAudioDidUseSpeechFallback)) { _ in
            audioFallbackToast = "Using voice — stream unavailable"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                audioFallbackToast = nil
            }
        }
        .overlay(alignment: .top) {
            if let toast = audioFallbackToast {
                Text(toast)
                    .font(.lexisCaptionM)
                    .foregroundColor(.dustGold)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.dustGold.opacity(0.35), lineWidth: 1))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 52)
            }
        }
        .animation(.spring(response: 0.35), value: audioFallbackToast)
    }

    // MARK: - Safe area helper
    private var deviceSafeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            .map { $0.safeAreaInsets.top }
            ?? 44
    }

    // MARK: - Active Session

    private var activeSessionStack: some View {
        GeometryReader { geo in
            let topInset = SessionChromeMetrics.totalTopInset(safeAreaTop: deviceSafeAreaTop)
            // Leave horizontal margins + bottom breathing room so the card floats
            let hPad: CGFloat = 12
            let bottomPad: CGFloat = 32
            let cardH = max(120, geo.size.height - topInset - bottomPad)
            let cardW = geo.size.width - hPad * 2
            let viewport = CGSize(width: cardW, height: cardH)

            VStack(spacing: 0) {
                sessionChromeHeader(safeTop: deviceSafeAreaTop)
                    .frame(height: topInset)
                    .frame(maxWidth: .infinity)

                // Card stack: next cards (image previews) + live card
                ZStack(alignment: .top) {
                    
                    let dragNorm = min(1.0, abs(vm.dragOffset.width) / 180.0)

                    if vm.currentIndex + 2 < vm.queue.count {
                        ReviewSessionStackPreviewCard(card: vm.queue[vm.currentIndex + 2])
                            .frame(width: cardW - 24, height: cardH - 20)
                            .offset(x: 3 - (dragNorm * 2), y: 18 - (dragNorm * 9))
                            .rotationEffect(.degrees(-1.2 + Double(dragNorm * 1.9)))
                            .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
                    }

                    if vm.currentIndex + 1 < vm.queue.count {
                        ReviewSessionStackPreviewCard(card: vm.queue[vm.currentIndex + 1])
                            .frame(width: cardW - 12 + (dragNorm * 12), height: cardH - 12 + (dragNorm * 12))
                            .offset(x: 1 - (dragNorm * 1), y: 9 - (dragNorm * 9))
                            .rotationEffect(.degrees(0.7 - Double(dragNorm * 0.7)))
                            .shadow(color: Color.black.opacity(0.16), radius: 14, y: 7)
                    }

                    // Main card
                    ZStack {
                        if let card = vm.currentCard {
                            SwipeCardView(
                                card: card,
                                isRevealed: vm.isCardRevealed,
                                viewport: viewport,
                                dragOffset: vm.dragOffset,
                                dragRotation: vm.dragRotation,
                                onToggleReveal: { vm.toggleRevealCard() },
                                onDrag: { translation in vm.updateDrag(translation) },
                                onDragEnd: {
                                    Task {
                                        let shouldShowFeedback = await vm.commitDrag()
                                        if shouldShowFeedback {
                                            await MainActor.run {
                                                Haptics.impact(.light)
                                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                                    cardPhase = .feedback
                                                }
                                            }
                                        }
                                    }
                                }
                            )
                            .frame(width: cardW, height: cardH)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 10)
                        } else {
                            // No card remaining in active state → auto-complete the session.
                            Color.clear
                                .task { await vm.endSession(reason: "completed") }
                        }

                        if cardPhase == .feedback, let card = vm.currentCard {
                            ZStack {
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .ignoresSafeArea()
                                    .transition(.opacity)
                                    .onTapGesture {
                                        // Block taps passing through to swipe layer
                                    }

                                FeedbackCardView(
                                    card: card,
                                    onRate: { rating in
                                        Haptics.impact(rating == .gotIt ? .medium : .light)
                                        Task { await vm.rateCard(rating) }
                                    },
                                    onBack: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                            cardPhase = .word
                                        }
                                    }
                                )
                                .frame(width: cardW, height: cardH)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: Color.black.opacity(0.2), radius: 30, y: 15)
                            }
                            .zIndex(10)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity,
                                    removal: .opacity
                                )
                            )
                        }
                    }
                    .frame(width: cardW, height: cardH)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, hPad)
                .animation(.spring(response: 0.38, dampingFraction: 0.82), value: cardPhase)
            }
        }
        .ignoresSafeArea(edges: [.top, .bottom])
    }

    // MARK: - Compact single-row chrome header (Phase 1)

    private func sessionChromeHeader(safeTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeTop)

            HStack(alignment: .center, spacing: Spacing.sm) {
                SessionProgressBar(progress: vm.progress)
                    .frame(maxWidth: .infinity)
                    .frame(height: SessionChromeMetrics.progressBarHeight)

                Text(vm.progressLabel)
                    .font(.lexisCaption)
                    .foregroundColor(.textTertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: 46, alignment: .trailing)

                Button {
                    Haptics.impact(.light)
                    Task { await vm.endSession(reason: "exited") }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(
                            width: SessionChromeMetrics.closeButtonSize,
                            height: SessionChromeMetrics.closeButtonSize
                        )
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("End session")
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, SessionChromeMetrics.rowTopPadding)
            .padding(.bottom, SessionChromeMetrics.rowBottomPadding)
            .frame(height: SessionChromeMetrics.innerChromeHeight)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            LinearGradient(
                colors: [Color.inkBlack.opacity(0.72), Color.inkBlack.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: Spacing.xl) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.cobaltBlue)
                .scaleEffect(1.4)
            Text("Preparing your session…")
                .font(.lexisBody)
                .foregroundColor(.textSecondary)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.streak)
            Text(msg)
                .font(.lexisBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxxl)

            Button("Try Again") {
                cardPhase = .word
                Task { await vm.startSession() }
            }
            .primaryStyle()
            .frame(width: 180)

            Button("Go Back", action: onDismiss)
                .ghostStyle(color: .textSecondary)
        }
    }
}

// MARK: - Stack preview (next cards behind swipe card)

private struct ReviewSessionStackPreviewCard: View {
    let card: ReviewQueueCard

    @State private var imageCache: UIImage?
    @State private var imageLoadFailed = false

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size
            ZStack {
                LexisBoundedImageView(
                    uiImage: imageCache,
                    loadFailed: imageLoadFailed,
                    initialLetter: String(card.word.term.prefix(1).uppercased()),
                    viewport: viewport,
                    kenBurnsActive: false,
                    reduceMotion: true
                )
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.inkBlack.opacity(0.42))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.glassBorder.opacity(0.55), lineWidth: 1)
            )
        }
        .allowsHitTesting(false)
        .task(id: card.wordId) { await loadImage() }
    }

    private func loadImage() async {
        await MainActor.run {
            imageCache = nil
            imageLoadFailed = false
        }
        guard let s = card.word.primaryImageUrl, let url = URL(string: s) else { return }

        if let cached = await ImagePrefetcher.shared.cachedData(for: s) {
            let ui = await Task.detached(priority: .utility) { UIImage(data: cached) }.value
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
            let ui = await Task.detached(priority: .utility) { UIImage(data: data) }.value
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

// MARK: - Review Ambient Background

private struct ReviewAmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient.session.ignoresSafeArea()

            if !reduceMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let pulse = 0.5 + 0.5 * sin(t * 0.25)
                    let cx = 0.5 + 0.2 * sin(t * 0.15)
                    
                    RadialGradient(
                        colors: [Color.cobaltBlue.opacity(0.12 + 0.08 * pulse), Color.clear],
                        center: UnitPoint(x: cx, y: 0.2),
                        startRadius: 50,
                        endRadius: 700
                    )
                    .ignoresSafeArea()
                    
                    RadialGradient(
                        colors: [Color.jadeGreen.opacity(0.06 + 0.04 * (1 - pulse)), Color.clear],
                        center: UnitPoint(x: 1 - cx, y: 0.8),
                        startRadius: 50,
                        endRadius: 600
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }
}

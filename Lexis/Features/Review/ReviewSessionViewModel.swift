import Foundation
import Observation
import SwiftUI

// MARK: - Session State Machine

enum SessionState: Equatable {
    case loading
    case active
    case completing
    case freeLimitHit
    case complete(SessionSummaryResponse, StreakResponse)
    /// Exited without completing: draft saved (if cards were rated) or empty session cleaned up.
    case dismissedWithoutSummary
    case error(String)

    static func == (lhs: SessionState, rhs: SessionState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.active, .active),
             (.completing, .completing), (.freeLimitHit, .freeLimitHit),
             (.dismissedWithoutSummary, .dismissedWithoutSummary): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - ViewModel

@Observable
final class ReviewSessionViewModel {
    var state: SessionState = .loading
    var queue: [ReviewQueueCard] = []
    var queueMeta: QueueMeta? = nil
    var currentIndex: Int = 0
    var sessionId: Int = 0
    var newWordCount: Int = 0

    var freeLimitPayload: (SessionSummaryResponse, StreakResponse)? = nil

    private(set) var sessionNewCardsRated: Int = 0
    private(set) var sessionReviewCardsRated: Int = 0

    var isCardRevealed: Bool = false
    var dragOffset: CGSize = .zero
    var dragRotation: Double = 0
    var cardExitDirection: CGFloat = 0
    var isExiting: Bool = false
    var totalXpEarned: Int = 0

    private var cardsRated: Int = 0
    private var ratedWordIds: [Int] = []
    private var sessionStartTime: Date = Date()
    private let FREE_CARD_LIMIT = 3
    private let api = APIClient.shared

    var onRatedCard: ((ReviewQueueCard, CardRating) -> Void)?

    // MARK: - Session Start

    func startSession(packId: Int? = nil) async {
        state = .loading
        cardsRated = 0
        ratedWordIds = []
        isCardRevealed = false
        totalXpEarned = 0
        sessionStartTime = Date()
        freeLimitPayload = nil
        sessionNewCardsRated = 0
        sessionReviewCardsRated = 0

        // --- Resume from saved draft ---
        if let draft = await SessionDraftStore.shared.load() {
            // Discard stale drafts where the saved index is past the queue end.
            if draft.currentIndex < draft.queue.count {
                await MainActor.run {
                    queue = draft.queue
                    sessionId = draft.sessionId
                    currentIndex = draft.currentIndex
                    ratedWordIds = draft.ratedWordIds
                    cardsRated = max(draft.cardsRated, draft.ratedWordIds.count)
                    sessionNewCardsRated = draft.sessionNewCardsRated
                    sessionReviewCardsRated = draft.sessionReviewCardsRated
                }
                let urls = draft.queue.dropFirst(draft.currentIndex).prefix(6)
                    .compactMap { $0.word.primaryImageUrl }
                await ImagePrefetcher.shared.prefetchFirstThenRest(urlStrings: urls)
                await MainActor.run { state = .active }
                return
            } else {
                // Corrupted/stale draft — clear it and fall through to a fresh BE session.
                await SessionDraftStore.shared.clear()
            }
        }

        // --- Fresh session from BE ---
        do {
            let response: ReviewQueueResponse = try await api.request(
                .getQueue(packId: packId, limit: 30, includeNew: true, newWordLimit: 5)
            )
            await MainActor.run {
                sessionId = response.sessionId
                queue = response.queue
                queueMeta = response.queueMeta
                newWordCount = response.queueMeta.newCards
                currentIndex = 0
            }

            let prefetchUrls = response.queue.prefix(8).compactMap { $0.word.primaryImageUrl }
            await ImagePrefetcher.shared.prefetchFirstThenRest(urlStrings: prefetchUrls)

            await MainActor.run { state = .active }

        } catch {
            await MainActor.run {
                state = .error((error as? LexisError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    // MARK: - Reveal / collapse card

    func toggleRevealCard() {
        guard state == .active else { return }
        isCardRevealed.toggle()
        dragOffset = .zero
        dragRotation = 0
    }

    // MARK: - Rate Card

    func rateCard(_ rating: CardRating) async {
        guard state == .active, currentIndex < queue.count else { return }
        let card = queue[currentIndex]
        let isFree = !AuthSession.shared.isProUser
        let elapsed = Int(Date().timeIntervalSince(sessionStartTime) * 1000)

        do {
            try await api.requestVoid(
                .rateCard(
                    sessionId: sessionId,
                    wordId: card.wordId,
                    rating: rating.rawValue,
                    responseTimeMs: elapsed,
                    cardType: card.cardType
                )
            )
            onRatedCard?(card, rating)
        } catch {
            // Still advance local UX; backend may retry on next session.
        }

        // Track rated words for draft resumption
        await MainActor.run { ratedWordIds.append(card.wordId) }

        let typeLower = card.cardType.lowercased()
        if typeLower == "new" {
            sessionNewCardsRated += 1
        } else {
            sessionReviewCardsRated += 1
        }

        cardsRated += 1

        if rating == .gotIt { totalXpEarned += 10 }
        else if rating == .almost { totalXpEarned += 5 }

        if isFree && cardsRated >= FREE_CARD_LIMIT {
            await finalizeSessionForFreeLimit()
            return
        }

        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isCardRevealed = false
                dragOffset = .zero
                dragRotation = 0
            }
        }

        if currentIndex + 1 >= queue.count {
            await endSession(reason: "completed")
        } else {
            await MainActor.run { currentIndex += 1 }
            let lookahead = [currentIndex + 1, currentIndex + 2].compactMap { queue[safe: $0]?.word.primaryImageUrl }
            if !lookahead.isEmpty {
                Task { await ImagePrefetcher.shared.prefetch(urlStrings: lookahead) }
            }
        }
    }

    @MainActor
    func promoteFreeLimitToComplete() {
        guard case .freeLimitHit = state, let payload = freeLimitPayload else { return }
        state = .complete(payload.0, payload.1)
    }

    // MARK: - Free limit → complete session

    private func finalizeSessionForFreeLimit() async {
        guard state == .active else { return }
        state = .completing

        do {
            async let summaryResult: SessionSummaryResponse = api.request(
                .completeSession(sessionId: sessionId, endedReason: "exited")
            )
            async let streakResult: StreakResponse = api.request(.getStreak)
            let (summary, streak) = try await (summaryResult, streakResult)
            await SessionDraftStore.shared.clear()
            SessionDraftStore.markSessionCompleted()
            freeLimitPayload = (summary, streak)
            state = .freeLimitHit
        } catch {
            SessionDraftStore.markSessionCompleted()
            let fallback = makeFallbackSummary()
            let fallbackStreak = StreakResponse(
                currentStreak: 0, longestStreak: 0,
                lastActivityDate: nil, freezeCredits: 0, history: []
            )
            freeLimitPayload = (fallback, fallbackStreak)
            state = .freeLimitHit
        }

        await MainActor.run {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isCardRevealed = false
                dragOffset = .zero
                dragRotation = 0
            }
        }
    }

    // MARK: - End Session

    func endSession(reason: String) async {
        guard state == .active else { return }

        // User closed the session (X): always persist draft so they can resume — including
        // before the first rating. Never call BE `completeSession` here; that was incorrectly
        // finalizing the server session and breaking resume from card 1.
        if reason == "exited" {
            let draft = SessionDraft(
                sessionId: sessionId,
                queue: queue,
                currentIndex: currentIndex,
                ratedWordIds: ratedWordIds,
                cardsRated: cardsRated,
                sessionNewCardsRated: sessionNewCardsRated,
                sessionReviewCardsRated: sessionReviewCardsRated,
                dayKey: SessionDraftStore.currentDayKey,
                savedAt: Date()
            )
            await SessionDraftStore.shared.save(draft)
            await MainActor.run { state = .dismissedWithoutSummary }
            return
        }

        // All cards rated → complete session normally
        state = .completing

        do {
            async let summaryResult: SessionSummaryResponse = api.request(
                .completeSession(sessionId: sessionId, endedReason: reason)
            )
            async let streakResult: StreakResponse = api.request(.getStreak)
            let (summary, streak) = try await (summaryResult, streakResult)
            await SessionDraftStore.shared.clear()
            SessionDraftStore.markSessionCompleted()
            await MainActor.run { state = .complete(summary, streak) }
        } catch {
            await SessionDraftStore.shared.clear()
            SessionDraftStore.markSessionCompleted()
            await MainActor.run { state = .complete(makeFallbackSummary(), makeFallbackStreak()) }
        }
    }

    // MARK: - Current Card

    var currentCard: ReviewQueueCard? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var nextCard: ReviewQueueCard? {
        let next = currentIndex + 1
        guard next < queue.count else { return nil }
        return queue[next]
    }

    /// Effective session length: capped to FREE_CARD_LIMIT for free users, full queue for Pro.
    var sessionCardCap: Int {
        if AuthSession.shared.isProUser {
            return max(1, queue.count)
        }
        return min(queue.count, FREE_CARD_LIMIT)
    }

    var progress: Double {
        let cap = sessionCardCap
        guard cap > 0 else { return 0 }
        return Double(currentIndex) / Double(cap)
    }

    /// "3 / 5" label shown alongside the progress bar.
    var progressLabel: String {
        "\(currentIndex) / \(sessionCardCap)"
    }

    var freeCardLimit: Int { FREE_CARD_LIMIT }

    var premiumUnlockCount: Int {
        max(0, (queueMeta?.totalCards ?? 0) - FREE_CARD_LIMIT)
    }

    var gateFreeNewWords: Int {
        max(0, (queueMeta?.newCards ?? 0) - min(FREE_CARD_LIMIT, queueMeta?.newCards ?? 0))
    }

    var gateFreeReviewWords: Int {
        max(0, (queueMeta?.reviewCards ?? 0) - min(FREE_CARD_LIMIT, queueMeta?.reviewCards ?? 0))
    }

    // MARK: - Swipe Drag State

    func updateDrag(_ translation: CGSize) {
        dragOffset = translation
        dragRotation = Double(translation.width / 22).clamped(to: -14...14)
    }

    @discardableResult
    func commitDrag() async -> Bool {
        let threshold: CGFloat = 110
        if dragOffset.width < -threshold {
            await snapBack()
            return true
        } else {
            await snapBack()
            return false
        }
    }

    private func snapBack() async {
        await MainActor.run {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                dragOffset = .zero
                dragRotation = 0
            }
        }
    }

    // MARK: - Helpers

    private func makeFallbackSummary() -> SessionSummaryResponse {
        SessionSummaryResponse(
            sessionId: sessionId,
            summary: SessionSummary(
                cardsSeen: cardsRated,
                cardsCorrect: 0,
                accuracyPct: 0,
                durationSeconds: Int(Date().timeIntervalSince(sessionStartTime)),
                xpEarned: totalXpEarned,
                streakUpdated: false,
                streakDay: 0,
                wordsMasteredToday: 0,
                milestonesUnlocked: nil
            ),
            nextSession: nil
        )
    }

    private func makeFallbackStreak() -> StreakResponse {
        StreakResponse(
            currentStreak: 0, longestStreak: 0,
            lastActivityDate: nil, freezeCredits: 0, history: []
        )
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

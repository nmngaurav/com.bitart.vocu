import Foundation
import Observation

@Observable
final class HomeViewModel {
    var user: UserBrief? = AuthSession.shared.currentUser
    var streak: StreakResponse? = nil
    var progress: ProgressSummaryResponse? = nil
    var packs: [PackSummaryResponse] = []

    /// Last successful API payloads — keeps Home stable when a refresh fails (nil decode / network).
    private(set) var lastKnownProgress: ProgressSummaryResponse? = nil
    private(set) var lastKnownStreak: StreakResponse? = nil

    var isLoading: Bool = false
    var errorMessage: String? = nil
    var hasPausedSession: Bool = false
    var completedSessionToday: Bool = false

    /// Packs request finished (success or failure); when true and `packs.isEmpty`, show library empty state — not shimmer.
    var packsLoadCompleted: Bool = false
    /// Start true so the packs row shows shimmer until the first list request completes.
    var packsAreLoading: Bool = true

    /// After the first `loadAll()` finishes, avoid flashing the full-screen loading skeleton on pull-to-refresh.
    private(set) var hasCompletedInitialHomeLoad: Bool = false

    /// Avoid repeated pack word fetches; prefetch is safe to skip after first success this VM lifetime.
    private var didWarmReviewImageCache = false

    var showReviewSession: Bool = false
    var libraryBrowsePack: PackSummaryResponse?

    private let api = APIClient.shared

    // MARK: - Load All Data (parallel)

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        packsAreLoading = true
        packsLoadCompleted = false

        defer { isLoading = false }

        // Refresh resume/completion state
        hasPausedSession = await SessionDraftStore.shared.hasDraftForToday
        completedSessionToday = SessionDraftStore.hasCompletedSessionToday()

        // Load independently so 403/empty guest responses don’t fail the whole screen or show decode toasts.
        let u: UserBrief? = try? await api.request(.getMe)
        let s: StreakResponse? = try? await api.request(.getStreak)
        let p: ProgressSummaryResponse? = try? await api.request(.progressSummary)
        if let u = u {
            user = u
            AuthSession.shared.updateUser(u)
        }
        if let s = s {
            streak = s
            lastKnownStreak = s
        }
        if let p = p {
            progress = p
            lastKnownProgress = p
        }
        errorMessage = nil

        let pk: [PackSummaryResponse] = (try? await api.request(.listPacks(isPremium: nil))) ?? []
        packs = pk
        packsAreLoading = false
        packsLoadCompleted = true
        hasCompletedInitialHomeLoad = true

        // Warm review images while user is on home. Do NOT call `getQueue` here — the backend
        // creates a ReviewSession and may insert new UserProgress rows on every queue fetch.
        Task {
            await warmReviewImageCacheFromPausedDraftIfNeeded()
            await warmReviewImageCacheFromFirstPackIfNeeded()
        }
    }

    /// Words in the saved draft are often not the same as `packs.first`; prefetch so resume is instant.
    private func warmReviewImageCacheFromPausedDraftIfNeeded() async {
        guard await SessionDraftStore.shared.hasDraftForToday else { return }
        guard let draft = await SessionDraftStore.shared.load() else { return }
        guard draft.currentIndex < draft.queue.count else { return }
        let urls = draft.queue[draft.currentIndex...]
            .prefix(8)
            .compactMap(\.word.primaryImageUrl)
        guard !urls.isEmpty else { return }
        await ImagePrefetcher.shared.prefetchFirstThenRest(urlStrings: urls)
    }

    /// Prefetch likely word art via `getPackWords` (read-only) for fresh sessions / first pack.
    private func warmReviewImageCacheFromFirstPackIfNeeded() async {
        guard !didWarmReviewImageCache else { return }
        guard let packId = packs.first?.id else { return }
        didWarmReviewImageCache = true
        do {
            let words: [PackWordProgressResponse] = try await api.request(
                .getPackWords(packId: packId, status: nil, limit: 16)
            )
            let urls = words.compactMap(\.primaryImageUrl)
            let prefix = Array(urls.prefix(8))
            guard !prefix.isEmpty else { return }
            await ImagePrefetcher.shared.prefetchFirstThenRest(urlStrings: prefix)
        } catch {
            didWarmReviewImageCache = false
        }
    }

    /// Streak for UI (live or last known).
    var resolvedStreak: StreakResponse? { effectiveStreak }

    // MARK: - Computed

    var greetingName: String {
        user?.displayNameOrFallback ?? "Learner"
    }

    /// Prefer live `progress`, fall back to last successful load so pull-to-refresh doesn’t flash “new user”.
    private var effectiveProgress: ProgressSummaryResponse? {
        progress ?? lastKnownProgress
    }

    private var effectiveStreak: StreakResponse? {
        streak ?? lastKnownStreak
    }

    var totalWordsSeen: Int {
        effectiveProgress?.totalWordsSeen ?? 0
    }

    /// True when the user has not completed any study tracked by the progress API.
    var isNewUser: Bool {
        totalWordsSeen == 0
    }

    /// Words “in play” for hero copy (new, learning, or due).
    var heroLibraryWordCount: Int {
        let p = effectiveProgress
        return max(p?.wordsNew ?? 0, p?.wordsLearning ?? 0, p?.dueToday ?? 0)
    }

    var reviewCTAPhase: HomeReviewCTAPhase {
        if isNewUser {
            return .newUser(libraryWordHint: heroLibraryWordCount)
        }
        if dueTodayCount > 0 {
            return .due(count: dueTodayCount, minutes: estimatedMinutes)
        }
        return .caughtUp
    }

    var dueTodayCount: Int {
        effectiveProgress?.dueToday ?? 0
    }

    var wordsLearned: Int {
        effectiveProgress?.wordsMastered ?? 0
    }

    var wordsLearning: Int {
        effectiveProgress?.wordsLearning ?? 0
    }

    var wordsNew: Int {
        effectiveProgress?.wordsNew ?? 0
    }

    var dailyGoal: Int {
        user?.preferences?.dailyGoal ?? 0
    }

    var currentStreak: Int {
        effectiveStreak?.currentStreak ?? 0
    }

    var streakHistory: [String] {
        effectiveStreak?.history ?? []
    }

    var estimatedMinutes: Int {
        max(1, Int(ceil(Double(dueTodayCount) * 0.25)))
    }

    var retentionPercent: Int {
        Int((effectiveProgress?.retentionRate ?? 0) * 100)
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Hey"
        }
    }
}

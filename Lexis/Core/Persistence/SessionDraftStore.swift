import Foundation

/// Thread-safe store for mid-session drafts and the completed-session flag.
actor SessionDraftStore {
    static let shared = SessionDraftStore()
    private init() {}

    private let draftKey = "vocu.sessionDraft"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Draft

    func save(_ draft: SessionDraft) {
        do {
            let data = try encoder.encode(draft)
            UserDefaults.standard.set(data, forKey: draftKey)
        } catch {
            #if DEBUG
            print("[Lexis] SessionDraftStore.save failed: \(error.localizedDescription)")
            #endif
        }
    }

    func load() -> SessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: draftKey) else {
            return nil
        }
        guard let draft = try? decoder.decode(SessionDraft.self, from: data) else {
            #if DEBUG
            print("[Lexis] SessionDraftStore.load: decode failed, clearing")
            #endif
            clear()
            return nil
        }
        guard draft.dayKey == SessionDraftStore.currentDayKey else {
            clear()
            return nil
        }
        return draft
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    var hasDraftForToday: Bool {
        load() != nil
    }

    // MARK: - Completed-session flag (nonisolated — just UserDefaults booleans)

    nonisolated static var currentDayKey: String {
        TodayWordActivityWriter.dayKey()
    }

    nonisolated static func markSessionCompleted() {
        UserDefaults.standard.set(true, forKey: completedKey(for: currentDayKey))
    }

    nonisolated static func hasCompletedSessionToday() -> Bool {
        UserDefaults.standard.bool(forKey: completedKey(for: currentDayKey))
    }

    private nonisolated static func completedKey(for dayKey: String) -> String {
        "vocu.completedSession.\(dayKey)"
    }
}

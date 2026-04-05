import Foundation

/// Local “collection” until a backend endpoint exists. Persists word IDs the user bookmarked during review.
final class SavedWordsStore {
    static let shared = SavedWordsStore()

    private let key = "vocu.savedWordIds"

    private init() {}

    private var idSet: Set<Int> {
        get {
            guard let arr = UserDefaults.standard.array(forKey: key) as? [Int] else { return [] }
            return Set(arr)
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: key)
        }
    }

    func contains(_ wordId: Int) -> Bool {
        idSet.contains(wordId)
    }

    @discardableResult
    func toggle(_ wordId: Int) -> Bool {
        var s = idSet
        if s.contains(wordId) {
            s.remove(wordId)
            idSet = s
            return false
        }
        s.insert(wordId)
        idSet = s
        return true
    }
}

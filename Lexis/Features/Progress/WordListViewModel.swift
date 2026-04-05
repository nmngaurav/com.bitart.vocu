import Foundation
import Observation

@Observable
final class WordListViewModel {
    var sessions: [SessionHistoryItem] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    private let api = APIClient.shared

    static func displayTitle(for item: SessionHistoryItem) -> String {
        let t = item.packTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Mixed deck review" : t
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list: [SessionHistoryItem] = try await api.request(.sessionHistory(packId: nil, limit: 60))
            sessions = list.filter { $0.cardsSeen > 0 }
        } catch {
            errorMessage = (error as? LexisError)?.errorDescription ?? error.localizedDescription
            sessions = []
        }
    }
}

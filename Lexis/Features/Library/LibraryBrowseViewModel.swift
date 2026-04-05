import Foundation
import Observation

@Observable
final class LibraryBrowseViewModel {
    var words: [PackWordProgressResponse] = []
    var isLoading: Bool = true
    var errorMessage: String?

    private let api = APIClient.shared

    func load(packId: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list: [PackWordProgressResponse] = try await api.request(
                .getPackWords(packId: packId, status: nil, limit: 80)
            )
            words = list
        } catch {
            errorMessage = (error as? LexisError)?.errorDescription ?? error.localizedDescription
            words = []
        }
    }
}

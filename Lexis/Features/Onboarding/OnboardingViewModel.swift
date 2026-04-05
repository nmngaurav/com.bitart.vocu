import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    var currentPage: Int = 0
    let totalPages = 4

    var isLastPage: Bool { currentPage == totalPages - 1 }

    func advance() {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 1
    }
}

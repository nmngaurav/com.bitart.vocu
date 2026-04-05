import Foundation

enum HomeReviewCTAPhase: Equatable {
    /// No progress yet — encourage first session (optional count from progress API).
    case newUser(libraryWordHint: Int)
    case due(count: Int, minutes: Int)
    /// Has studied before; nothing due today.
    case caughtUp
}

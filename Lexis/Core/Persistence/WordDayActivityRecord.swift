import Foundation
import SwiftData

/// One row per (calendar day, word) for local “today” recap — browse + review ratings.
@Model
final class WordDayActivityRecord {
    @Attribute(.unique) var stableId: String
    var wordId: Int
    var term: String
    var dayKey: String
    var firstSeenAt: Date
    var lastUpdatedAt: Date
    /// "library" | "review"
    var sourceRaw: String
    var ratingLabel: String?
    var cardType: String?
    var imageUrl: String?
    /// Snapshot for recap (same session as review card back face).
    var definitionText: String?
    var exampleText: String?
    var phoneticText: String?
    var partOfSpeechText: String?
    var audioUrlString: String?

    init(
        stableId: String,
        wordId: Int,
        term: String,
        dayKey: String,
        firstSeenAt: Date,
        lastUpdatedAt: Date,
        sourceRaw: String,
        ratingLabel: String?,
        cardType: String?,
        imageUrl: String?,
        definitionText: String? = nil,
        exampleText: String? = nil,
        phoneticText: String? = nil,
        partOfSpeechText: String? = nil,
        audioUrlString: String? = nil
    ) {
        self.stableId = stableId
        self.wordId = wordId
        self.term = term
        self.dayKey = dayKey
        self.firstSeenAt = firstSeenAt
        self.lastUpdatedAt = lastUpdatedAt
        self.sourceRaw = sourceRaw
        self.ratingLabel = ratingLabel
        self.cardType = cardType
        self.imageUrl = imageUrl
        self.definitionText = definitionText
        self.exampleText = exampleText
        self.phoneticText = phoneticText
        self.partOfSpeechText = partOfSpeechText
        self.audioUrlString = audioUrlString
    }
}

enum WordActivitySource: String {
    case library
    case review
}

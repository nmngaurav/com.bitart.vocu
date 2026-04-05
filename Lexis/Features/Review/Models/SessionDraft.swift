import Foundation

/// Persisted mid-session snapshot that enables resuming an interrupted review.
struct SessionDraft: Codable {
    let sessionId: Int
    let queue: [ReviewQueueCard]
    let currentIndex: Int
    let ratedWordIds: [Int]
    let cardsRated: Int
    let sessionNewCardsRated: Int
    let sessionReviewCardsRated: Int
    let dayKey: String
    let savedAt: Date

    enum CodingKeys: String, CodingKey {
        case sessionId, queue, currentIndex, ratedWordIds, cardsRated
        case sessionNewCardsRated, sessionReviewCardsRated, dayKey, savedAt
    }

    init(
        sessionId: Int,
        queue: [ReviewQueueCard],
        currentIndex: Int,
        ratedWordIds: [Int],
        cardsRated: Int,
        sessionNewCardsRated: Int,
        sessionReviewCardsRated: Int,
        dayKey: String,
        savedAt: Date
    ) {
        self.sessionId = sessionId
        self.queue = queue
        self.currentIndex = currentIndex
        self.ratedWordIds = ratedWordIds
        self.cardsRated = cardsRated
        self.sessionNewCardsRated = sessionNewCardsRated
        self.sessionReviewCardsRated = sessionReviewCardsRated
        self.dayKey = dayKey
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(Int.self, forKey: .sessionId)
        queue = try c.decode([ReviewQueueCard].self, forKey: .queue)
        currentIndex = try c.decode(Int.self, forKey: .currentIndex)
        ratedWordIds = try c.decode([Int].self, forKey: .ratedWordIds)
        dayKey = try c.decode(String.self, forKey: .dayKey)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        if let cr = try c.decodeIfPresent(Int.self, forKey: .cardsRated) {
            cardsRated = cr
        } else {
            cardsRated = ratedWordIds.count
        }
        sessionNewCardsRated = try c.decodeIfPresent(Int.self, forKey: .sessionNewCardsRated) ?? 0
        sessionReviewCardsRated = try c.decodeIfPresent(Int.self, forKey: .sessionReviewCardsRated) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encode(queue, forKey: .queue)
        try c.encode(currentIndex, forKey: .currentIndex)
        try c.encode(ratedWordIds, forKey: .ratedWordIds)
        try c.encode(cardsRated, forKey: .cardsRated)
        try c.encode(sessionNewCardsRated, forKey: .sessionNewCardsRated)
        try c.encode(sessionReviewCardsRated, forKey: .sessionReviewCardsRated)
        try c.encode(dayKey, forKey: .dayKey)
        try c.encode(savedAt, forKey: .savedAt)
    }
}

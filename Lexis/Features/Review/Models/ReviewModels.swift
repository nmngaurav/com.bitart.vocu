import Foundation
import SwiftUI

// MARK: - Queue

struct ReviewQueueResponse: Codable {
    let sessionId: Int
    let queue: [ReviewQueueCard]
    let queueMeta: QueueMeta
}

struct ReviewQueueCard: Codable, Identifiable {
    var id: Int { wordId }
    let wordId: Int
    let cardType: String    // "new" | "review" | "challenge"
    let word: CardWordDetail
    let progress: CardProgress
}

struct CardWordDetail: Codable {
    let term: String
    let phonetic: String?
    let partOfSpeech: String?
    let definition: String
    let audioUrl: String?
    let primaryImageUrl: String?
    let example: String?
}

struct CardProgress: Codable {
    let repetitionCount: Int
    let memoryStrength: Double
}

struct QueueMeta: Codable {
    let totalCards: Int
    let newCards: Int
    let reviewCards: Int
    let estimatedMinutes: Int
}

// MARK: - Rating

struct RateCardRequest: Encodable {
    let wordId: Int
    let rating: Int         // 0 = tooSoon, 1 = almost, 2 = gotIt
    let responseTimeMs: Int
    let cardType: String
}

struct RateCardResponse: Decodable {
    let wordId: Int
    let nextReviewAt: String?
    let intervalDays: Int
    let easinessFactor: Double
    let memoryStrength: Double
    let xpEarned: Int
}

// MARK: - Session

struct CreateSessionResponse: Decodable {
    let sessionId: Int
    let startedAt: String?
}

struct SessionSummaryResponse: Decodable {
    let sessionId: Int
    let summary: SessionSummary
    let nextSession: NextSession?
}

struct SessionSummary: Decodable {
    let cardsSeen: Int
    let cardsCorrect: Int
    let accuracyPct: Int
    let durationSeconds: Int
    let xpEarned: Int
    let streakUpdated: Bool     // NOTE: always false from backend, use fresh /streak call
    let streakDay: Int          // NOTE: always 0 from backend, use fresh /streak call
    let wordsMasteredToday: Int
    let milestonesUnlocked: [Milestone]?
}

struct NextSession: Decodable {
    let dueCardCount: Int?
    let nextDueAt: String?
}

struct Milestone: Decodable, Identifiable {
    var id: String { "\(type)-\(value)" }
    let type: String
    let value: Int
    let message: String
}

// MARK: - Session History

struct SessionHistoryItem: Decodable, Identifiable {
    let id: Int
    let packId: Int?
    let packTitle: String?
    let cardsSeen: Int
    let accuracyPct: Int
    let durationSeconds: Int
    let startedAt: String?
}

// MARK: - Rating Enum

enum CardRating: Int, CaseIterable {
    case tooSoon = 0
    case almost = 1
    case gotIt = 2

    var label: String {
        switch self {
        case .tooSoon: return "Didn't Know"
        case .almost:  return "Almost"
        case .gotIt:   return "Got It!"
        }
    }

    var description: String {
        switch self {
        case .tooSoon: return "I'll get it next time"
        case .almost:  return "Was close"
        case .gotIt:   return "I knew this one"
        }
    }

    var accentColor: Color {
        switch self {
        case .tooSoon: return .coralRed
        case .almost:  return .dustGold
        case .gotIt:   return .jadeGreen
        }
    }

    var iconName: String {
        switch self {
        case .tooSoon: return "xmark.circle.fill"
        case .almost:  return "minus.circle.fill"
        case .gotIt:   return "checkmark.circle.fill"
        }
    }

    /// Resolve a stored label string back to its accent color (used in recap).
    static func accentColor(forLabel label: String) -> Color {
        allCases.first { $0.label == label }?.accentColor ?? .cobaltBlue
    }
}

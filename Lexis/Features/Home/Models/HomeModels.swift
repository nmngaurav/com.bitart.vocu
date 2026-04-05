import Foundation

// MARK: - Streak

struct StreakResponse: Decodable {
    let currentStreak: Int
    let longestStreak: Int
    let lastActivityDate: String?
    let freezeCredits: Int
    let history: [String]
}

// MARK: - Progress Summary

struct ProgressSummaryResponse: Decodable {
    let totalWordsSeen: Int
    let wordsMastered: Int
    let wordsLearning: Int
    let wordsNew: Int
    let retentionRate: Double
    let byPack: [PackProgressItem]?
    let weeklyXp: [Int]?
    let dueToday: Int
}

struct PackProgressItem: Decodable, Identifiable {
    var id: Int { packId }
    let packId: Int
    let packTitle: String
    let mastered: Int
    let total: Int
    let completionPct: Int
}

// MARK: - Pack

struct PackSummaryResponse: Decodable, Identifiable, Hashable {
    let id: Int
    let title: String
    let slug: String?
    let packType: String?
    let difficultyLevel: Int?
    let wordCount: Int
    let isPremium: Bool
    let pricePaise: Int?
    let access: PackAccess
    let meta: PackMeta?
}

struct PackAccess: Decodable, Hashable {
    let hasAccess: Bool
    let accessSource: String?
}

struct PackMeta: Decodable, Hashable {
    let coverImageUrl: String?
    let description: String?
    let tags: [String]?
}

// MARK: - Pack packs response wrapper

struct PacksListResponse: Decodable {
    let packs: [PackSummaryResponse]?
    // The API returns an array directly at data level
}

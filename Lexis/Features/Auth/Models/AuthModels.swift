import Foundation

// MARK: - Auth Response

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: UserBrief
    let expiresIn: Int
}

struct RefreshResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
}

// MARK: - User

struct UserStatsBrief: Decodable {
    let wordsLearned: Int?
    let currentStreak: Int?
    let longestStreak: Int?
    let totalSessions: Int?
}

struct UserPreferencesPayload: Decodable {
    let dailyGoal: Int?
    let notificationTime: String?

    enum CodingKeys: String, CodingKey {
        case dailyGoal = "daily_goal"
        case notificationTime = "notification_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) {
            dailyGoal = i
        } else if let d = try c.decodeIfPresent(Double.self, forKey: .dailyGoal) {
            dailyGoal = Int(d)
        } else {
            dailyGoal = nil
        }
        notificationTime = try c.decodeIfPresent(String.self, forKey: .notificationTime)
    }
}

struct UserBrief: Decodable, Identifiable {
    let id: Int
    let email: String?
    let displayName: String?
    let authType: String
    let subscriptionTier: String
    let createdAt: String?
    let preferences: UserPreferencesPayload?
    let stats: UserStatsBrief?

    var displayNameOrFallback: String {
        displayName ?? email?.components(separatedBy: "@").first ?? "Learner"
    }
}

import Foundation

enum Endpoint {
    // MARK: - Auth (public — no auth header required)
    case anonymous
    case register(email: String, password: String, displayName: String)
    case login(email: String, password: String)
    case oauthLogin(provider: String, idToken: String)
    case refreshToken(refreshToken: String)
    case logout

    // MARK: - Users
    case getMe
    case updateMe(displayName: String?, preferences: [String: Any]?)
    case deleteMe
    case getStreak

    // MARK: - Review  (getQueue ALSO creates a session server-side)
    case getQueue(packId: Int?, limit: Int, includeNew: Bool, newWordLimit: Int)
    case createSession(packId: Int?, mode: String)
    case rateCard(sessionId: Int, wordId: Int, rating: Int, responseTimeMs: Int, cardType: String)
    case completeSession(sessionId: Int, endedReason: String)
    case sessionHistory(packId: Int?, limit: Int)

    // MARK: - Progress
    case progressSummary

    // MARK: - Packs
    case listPacks(isPremium: Bool?)
    case getPackDetail(packId: Int)
    case getPackWords(packId: Int, status: String?, limit: Int)

    // MARK: - Subscription (listPlans is public)
    case listPlans
    case mySubscription
    case createSubscription(provider: String, purchaseToken: String, planId: String)

    // MARK: - Notifications
    case registerPushToken(token: String)
    case deregisterPushToken
}

// MARK: - URL + HTTPMethod Resolution

extension Endpoint {
    private static let base = "http://localhost:8000/api/v1"

    var urlString: String {
        switch self {
        case .anonymous:               return "\(Self.base)/auth/anonymous"
        case .register:                return "\(Self.base)/auth/register"
        case .login:                   return "\(Self.base)/auth/login"
        case .oauthLogin:              return "\(Self.base)/auth/oauth"
        case .refreshToken:            return "\(Self.base)/auth/refresh"
        case .logout:                  return "\(Self.base)/auth/logout"

        case .getMe:                   return "\(Self.base)/users/me"
        case .updateMe:                return "\(Self.base)/users/me"
        case .deleteMe:                return "\(Self.base)/users/me"
        case .getStreak:               return "\(Self.base)/users/me/streak"

        case .getQueue(let packId, let limit, let includeNew, let newWordLimit):
            var url = "\(Self.base)/review/queue?limit=\(limit)&include_new=\(includeNew)&new_word_limit=\(newWordLimit)"
            if let pid = packId { url += "&pack_id=\(pid)" }
            return url
        case .createSession:           return "\(Self.base)/review/sessions"
        case .rateCard(let sid, _, _, _, _):
            return "\(Self.base)/review/sessions/\(sid)/rate"
        case .completeSession(let sid, _):
            return "\(Self.base)/review/sessions/\(sid)/complete"
        case .sessionHistory(let packId, let limit):
            var url = "\(Self.base)/review/sessions?limit=\(limit)"
            if let pid = packId { url += "&pack_id=\(pid)" }
            return url

        case .progressSummary:         return "\(Self.base)/progress/summary"

        case .listPacks(let isPremium):
            if let p = isPremium { return "\(Self.base)/packs?is_premium=\(p)" }
            return "\(Self.base)/packs"
        case .getPackDetail(let packId):
            return "\(Self.base)/packs/\(packId)"
        case .getPackWords(let packId, let status, let limit):
            var url = "\(Self.base)/packs/\(packId)/words?limit=\(limit)"
            if let s = status, !s.isEmpty,
               let enc = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                url += "&status=\(enc)"
            }
            return url

        case .listPlans:               return "\(Self.base)/subscriptions/plans"
        case .mySubscription:          return "\(Self.base)/subscriptions/me"
        case .createSubscription:      return "\(Self.base)/subscriptions"

        case .registerPushToken:       return "\(Self.base)/notifications/token"
        case .deregisterPushToken:     return "\(Self.base)/notifications/token"
        }
    }

    var method: String {
        switch self {
        case .getMe, .getStreak, .getQueue, .sessionHistory,
             .progressSummary, .listPacks, .getPackDetail, .getPackWords, .listPlans,
             .mySubscription: return "GET"

        case .updateMe: return "PATCH"
        case .deleteMe, .deregisterPushToken: return "DELETE"

        default: return "POST"
        }
    }

    var body: Data? {
        var dict: [String: Any] = [:]
        switch self {
        case .anonymous, .logout, .deleteMe, .getMe, .getStreak, .getQueue,
             .sessionHistory, .progressSummary, .listPacks, .getPackDetail, .getPackWords,
             .listPlans, .mySubscription, .deregisterPushToken:
            return nil

        case .register(let email, let password, let name):
            dict = ["email": email, "password": password, "display_name": name]

        case .login(let email, let password):
            dict = ["email": email, "password": password]

        case .oauthLogin(let provider, let idToken):
            dict = ["provider": provider, "id_token": idToken]

        case .refreshToken(let token):
            dict = ["refresh_token": token]

        case .updateMe(let name, let prefs):
            if let n = name { dict["display_name"] = n }
            if let p = prefs { dict["preferences"] = p }

        case .createSession(let packId, let mode):
            dict["mode"] = mode
            if let pid = packId { dict["pack_id"] = pid }

        case .rateCard(_, let wordId, let rating, let ms, let cardType):
            dict = ["word_id": wordId, "rating": rating, "response_time_ms": ms, "card_type": cardType]

        case .completeSession(_, let reason):
            dict = ["ended_reason": reason]

        case .createSubscription(let provider, let token, let planId):
            dict = ["provider": provider, "purchase_token": token, "plan_id": planId]

        case .registerPushToken(let token):
            dict = ["token": token, "platform": "ios"]
        }
        return try? JSONSerialization.data(withJSONObject: dict)
    }

    var requiresAuth: Bool {
        switch self {
        case .anonymous, .register, .login, .oauthLogin, .refreshToken, .listPlans:
            return false
        default:
            return true
        }
    }
}

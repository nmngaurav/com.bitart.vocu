import Foundation
import Observation

// MARK: - Auth Session (app-wide observable state)

@Observable
final class AuthSession {
    static let shared = AuthSession()
    private init() {}

    var currentUser: UserBrief?
    var isAuthenticated: Bool = false

    var subscriptionTier: String {
        currentUser?.subscriptionTier ?? "FREE"
    }

    var isProUser: Bool {
        subscriptionTier.uppercased() == "PRO"
    }

    var isAnonymous: Bool {
        currentUser?.authType.uppercased() == "ANONYMOUS"
    }

    var anonymousAccessToken: String? {
        guard isAnonymous else { return nil }
        return TokenStore.shared.accessToken
    }

    func login(user: UserBrief, authResponse: AuthResponse) {
        TokenStore.shared.save(authResponse: authResponse)
        currentUser = user
        isAuthenticated = true
    }

    func updateUser(_ user: UserBrief) {
        currentUser = user
    }

    func signOut() {
        TokenStore.shared.clear()
        currentUser = nil
        isAuthenticated = false
    }
}

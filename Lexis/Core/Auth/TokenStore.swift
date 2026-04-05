import Foundation
import KeychainAccess

// MARK: - Token Store (Keychain-backed)

final class TokenStore: @unchecked Sendable {
    static let shared = TokenStore()
    private init() {}

    private let keychain = Keychain(service: "com.bitart.vocu")

    var accessToken: String? {
        get { try? keychain.get("access_token") }
        set {
            if let v = newValue { try? keychain.set(v, key: "access_token") }
            else { try? keychain.remove("access_token") }
        }
    }

    var refreshToken: String? {
        get { try? keychain.get("refresh_token") }
        set {
            if let v = newValue { try? keychain.set(v, key: "refresh_token") }
            else { try? keychain.remove("refresh_token") }
        }
    }

    var hasValidTokens: Bool {
        accessToken != nil && refreshToken != nil
    }

    func save(authResponse: AuthResponse) {
        accessToken = authResponse.accessToken
        refreshToken = authResponse.refreshToken
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
    }
}

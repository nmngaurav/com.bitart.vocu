import Foundation
import Observation
import AuthenticationServices
import UIKit

@Observable
final class AuthViewModel: NSObject {
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var showEmailSignIn: Bool = false

    /// Retained while `ASAuthorizationController` is active (delegate is weak).
    private var appleAuthorizationController: ASAuthorizationController?

    // Email fields
    var email: String = ""
    var password: String = ""
    var displayName: String = ""
    var isRegisterMode: Bool = false

    private let api = APIClient.shared
    private let authSession = AuthSession.shared

    var onSuccess: (() -> Void)?

    // MARK: - Google (using email simulation — backend treats id_token as email)
    func signInWithGoogle() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Present email input to get Google email
            // Real implementation: GoogleSignIn SDK -> credential.user.userID
            // Backend dev note: id_token is used directly as email
            await MainActor.run { showEmailSignIn = true }
        }
    }

    func signInWithGoogleEmail(_ email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let anonToken = authSession.anonymousAccessToken
            let response: AuthResponse = try await api.request(
                .oauthLogin(provider: "google", idToken: email),
                anonymousTokenOverride: nil
            )
            // Pass anonymous token in header for progress merge
            let mergedResponse: AuthResponse
            if let _ = anonToken {
                mergedResponse = try await api.request(
                    .oauthLogin(provider: "google", idToken: email),
                    anonymousTokenOverride: anonToken
                )
            } else {
                mergedResponse = response
            }
            await finish(with: mergedResponse)
        } catch {
            await MainActor.run {
                errorMessage = Self.mapAuthError(error)
            }
        }
    }

    // MARK: - Apple Sign In (programmatic — matches icon-only provider row)
    func performSignInWithApple() {
        guard !isLoading else { return }
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        appleAuthorizationController = controller
        controller.performRequests()
    }

    func handleAppleCredential(_ authorization: ASAuthorization) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            await MainActor.run { errorMessage = "Apple Sign In failed." }
            return
        }

        do {
            let anonToken = authSession.anonymousAccessToken
            let response: AuthResponse = try await api.request(
                .oauthLogin(provider: "apple", idToken: idToken),
                anonymousTokenOverride: anonToken
            )
            await finish(with: response)
        } catch {
            await MainActor.run {
                errorMessage = Self.mapAuthError(error)
            }
        }
    }

    // MARK: - Anonymous (Continue as Guest)
    func continueAsGuest() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: AuthResponse = try await api.request(.anonymous)
            await finish(with: response)
        } catch {
            await MainActor.run {
                errorMessage = Self.mapAuthError(error)
            }
        }
    }

    // MARK: - Email Auth
    func submitEmailAuth() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard trimmedPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        if isRegisterMode {
            guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Enter your name."
                return
            }
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: AuthResponse
            if isRegisterMode {
                let anonToken = authSession.anonymousAccessToken
                response = try await api.request(
                    .register(email: trimmedEmail, password: trimmedPassword, displayName: displayName),
                    anonymousTokenOverride: anonToken
                )
            } else {
                response = try await api.request(.login(email: trimmedEmail, password: trimmedPassword))
            }
            await finish(with: response)
        } catch {
            await MainActor.run {
                errorMessage = Self.mapAuthError(error)
            }
        }
    }

    /// Maps API/auth errors to user-facing copy; logs verification-related cases clearly on iOS.
    private static func mapAuthError(_ error: Error) -> String {
        if let lexis = error as? LexisError {
            switch lexis {
            case .apiError(let api):
                let m = api.message.lowercased()
                if m.contains("verify") || m.contains("verification") || m.contains("unverified") {
                    return "Please check your inbox and verify your email before signing in."
                }
                return api.message
            default:
                return lexis.errorDescription ?? error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Shared Finish

    private func finish(with response: AuthResponse) async {
        authSession.login(user: response.user, authResponse: response)
        // Register push token
        if let token = await getAPNSToken() {
            try? await api.requestVoid(.registerPushToken(token: token))
        }
        await MainActor.run {
            onSuccess?()
        }
    }

    private func getAPNSToken() async -> String? {
        // Returns cached APNS token if available
        return UserDefaults.standard.string(forKey: "apns_token")
    }
}

// MARK: - Sign in with Apple (ASAuthorizationController)

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        appleAuthorizationController = nil
        Task { await handleAppleCredential(authorization) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        appleAuthorizationController = nil
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return
        }
        Task { @MainActor in
            errorMessage = authErrorDescription(error)
        }
    }

    private func authErrorDescription(_ error: Error) -> String {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled: return ""
            case .failed: return "Sign in with Apple failed."
            case .invalidResponse: return "Invalid response from Apple."
            case .notHandled: return "Sign in with Apple could not be handled."
            case .unknown: return authError.localizedDescription
            case .notInteractive: return "Sign in with Apple is not available."
            @unknown default: return authError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first ?? UIWindow(frame: .zero)
    }
}

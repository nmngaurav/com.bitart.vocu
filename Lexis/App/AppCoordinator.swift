import SwiftUI
import Observation

// MARK: - App Root State

enum AppRoute {
    case loading
    case onboarding
    case auth
    case main
}

@Observable
final class AppCoordinator {
    var route: AppRoute = .loading

    /// `LexisApp` applies `.id(themeManager.refreshToken)` so the root view is recreated on
    /// theme changes; without this guard, `.task { determineInitialRoute() }` runs again and a
    /// transient `getMe` failure can clear tokens and send the user back to sign-in.
    private var didRunInitialRoute = false

    private let tokenStore = TokenStore.shared
    private let authSession = AuthSession.shared

    /// UserDefaults is removed on app delete; Keychain entries can occasionally survive (device
    /// transfer edge cases, offload/reinstall quirks, simulator). Without this, `hasValidTokens`
    /// could be true while onboarding flags are reset — skipping onboarding and showing main.
    private static let installSessionDefaultsKey = "vocu_device_install_id"

    func determineInitialRoute() async {
        guard !didRunInitialRoute else { return }
        defer { didRunInitialRoute = true }

        await coalesceInstallSessionWithKeychain()

        let splashStarted = Date()
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")

        let nextRoute: AppRoute

        if tokenStore.hasValidTokens {
            do {
                let user: UserBrief = try await APIClient.shared.request(.getMe)
                await MainActor.run {
                    authSession.updateUser(user)
                    authSession.isAuthenticated = true
                }
                nextRoute = .main
            } catch LexisError.unauthorized {
                do {
                    _ = try await APIClient.shared.refreshAccessToken()
                    let user: UserBrief = try await APIClient.shared.request(.getMe)
                    await MainActor.run {
                        authSession.updateUser(user)
                        authSession.isAuthenticated = true
                    }
                    nextRoute = .main
                } catch {
                    tokenStore.clear()
                    nextRoute = hasSeenOnboarding ? .auth : .onboarding
                }
            } catch LexisError.forbidden {
                await MainActor.run {
                    authSession.isAuthenticated = true
                }
                nextRoute = .main
            } catch {
                tokenStore.clear()
                nextRoute = hasSeenOnboarding ? .auth : .onboarding
            }
        } else {
            nextRoute = hasSeenOnboarding ? .auth : .onboarding
        }

        await waitMinimumSplashDuration(from: splashStarted)
        await MainActor.run {
            route = nextRoute
        }
    }

    /// If there is no install marker in UserDefaults, treat this as a new app install and drop
    /// any Keychain tokens so routing follows onboarding / sign-in instead of a stale session.
    private func coalesceInstallSessionWithKeychain() async {
        guard UserDefaults.standard.string(forKey: Self.installSessionDefaultsKey) == nil else {
            return
        }
        await MainActor.run {
            authSession.signOut()
        }
        UserDefaults.standard.set(UUID().uuidString, forKey: Self.installSessionDefaultsKey)
    }

    /// Keeps `LoadingSplashView` visible long enough for a premium first beat (cold start).
    private func waitMinimumSplashDuration(from start: Date) async {
        let minimum: TimeInterval = 1.65
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed < minimum else { return }
        let ns = UInt64((minimum - elapsed) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        route = .auth
    }

    func navigateToMain() {
        route = .main
    }

    /// Guest or signed-in user opens the auth / upgrade flow without clearing the session first.
    func openAuthFlow() {
        route = .auth
    }

    func signOut() {
        Task {
            try? await APIClient.shared.requestVoid(.logout)
            try? await APIClient.shared.requestVoid(.deregisterPushToken)
        }
        authSession.signOut()
        route = .auth
    }
}

// MARK: - Root View

struct AppCoordinatorView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()

            switch coordinator.route {
            case .loading:
                LoadingSplashView()
                    .transition(.opacity)

            case .onboarding:
                OnboardingView()
                    .transition(.opacity)

            case .auth:
                SoftPaywallAuthView()
                    .transition(.opacity)

            case .main:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: coordinator.route)
        .onAppear { themeManager.updateSystemColorScheme(colorScheme) }
        .onChange(of: colorScheme) { _, new in themeManager.updateSystemColorScheme(new) }
        .task {
            await coordinator.determineInitialRoute()
        }
    }
}

// MARK: - Loading Splash

struct LoadingSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var markOpacity: Double = 0
    @State private var markScale: CGFloat = 0.88
    @State private var wordmarkOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var glowPulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            splashBackdrop.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(Color.cobaltBlue.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .frame(width: 118, height: 118)
                        .blur(radius: 28)
                        .scaleEffect(glowPulse)

                    Circle()
                        .fill(LinearGradient.hero)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.cobaltBlue.opacity(0.42), radius: 22, y: 10)

                    Text("v")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .scaleEffect(markScale)
                .opacity(markOpacity)

                Text("vocu")
                    .font(.lexisDisplay2)
                    .foregroundColor(.moonPearl)
                    .opacity(wordmarkOpacity)

                Text("Learn words that stick—with context and smart repetition.")
                    .font(.lexisBody)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Spacing.xxxl)
                    .opacity(taglineOpacity)
            }
            .padding(.bottom, 40)
        }
        .onAppear(perform: playEntryAnimation)
    }

    private var splashBackdrop: some View {
        ZStack {
            Color.inkBlack
            RadialGradient(
                colors: [
                    Color.cobaltBlue.opacity(colorScheme == .dark ? 0.2 : 0.11),
                    Color.inkBlack.opacity(0.94),
                    Color.inkBlack
                ],
                center: .top,
                startRadius: 24,
                endRadius: 460
            )
        }
    }

    private func playEntryAnimation() {
        if reduceMotion {
            markOpacity = 1
            markScale = 1
            wordmarkOpacity = 1
            taglineOpacity = 1
            return
        }
        withAnimation(.spring(response: 0.78, dampingFraction: 0.82)) {
            markOpacity = 1
            markScale = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            wordmarkOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.75).delay(0.45)) {
            taglineOpacity = 1
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowPulse = 1.09
        }
    }
}

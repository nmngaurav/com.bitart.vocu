import SwiftData
import SwiftUI

@main
struct LexisApp: App {
    @State private var appCoordinator = AppCoordinator()
    /// Shared singleton — `@Observable` so `appearance` / `refreshToken` changes refresh the root (`\.id` + color tokens).
    @State private var themeManager = ThemeManager.shared

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 50_000_000,
            diskCapacity:  200_000_000
        )
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView()
                .environment(appCoordinator)
                .environment(themeManager)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                // Rebuild when palette changes. `determineInitialRoute()` is guarded so this does
                // not re-fetch session / clear tokens on every theme toggle.
                .id(themeManager.refreshToken)
        }
        .modelContainer(for: WordDayActivityRecord.self)
    }
}

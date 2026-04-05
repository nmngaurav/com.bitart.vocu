import Observation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme Manager

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let appearanceKey = "vocu.appearanceMode"
    private let legacyThemeKey = "vocu.appTheme"

    /// Bumps when appearance or resolved palette may change (drives `Color` token refresh).
    private(set) var refreshToken: Int = 0

    var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: appearanceKey)
            refreshToken &+= 1
        }
    }

    /// Latest `colorScheme` from SwiftUI environment (follows system when appearance is Auto).
    private(set) var systemColorScheme: ColorScheme = .light {
        didSet {
            if systemColorScheme != oldValue {
                refreshToken &+= 1
            }
        }
    }

    var effectiveColorScheme: ColorScheme {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system: return systemColorScheme
        }
    }

    var palette: SemanticPalette {
        SemanticPalette.palette(for: effectiveColorScheme)
    }

    private init() {
        #if canImport(UIKit)
        if Thread.isMainThread {
            systemColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
        #endif
        let resolved: AppearanceMode
        if let raw = UserDefaults.standard.string(forKey: appearanceKey),
           let mode = AppearanceMode(rawValue: raw) {
            resolved = mode
        } else if let legacyRaw = UserDefaults.standard.string(forKey: legacyThemeKey),
                  let legacy = LegacyAppTheme(rawValue: legacyRaw) {
            switch legacy {
            case .nightBlue, .midnight: resolved = .dark
            case .light: resolved = .light
            }
            UserDefaults.standard.set(resolved.rawValue, forKey: appearanceKey)
        } else {
            resolved = .light
            UserDefaults.standard.set(resolved.rawValue, forKey: appearanceKey)
        }
        appearance = resolved
    }

    func updateSystemColorScheme(_ scheme: ColorScheme) {
        systemColorScheme = scheme
    }
}

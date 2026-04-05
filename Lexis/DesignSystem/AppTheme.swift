import SwiftUI

// MARK: - Appearance (user setting)

enum AppearanceMode: String, CaseIterable, Identifiable, Hashable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Auto"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    /// `nil` follows the system (Auto).
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Semantic palette (light / dark)

struct SemanticPalette {
    var inkBlack: Color
    var deepNavy: Color
    var surfaceCard: Color
    var moonPearl: Color
    var textSecondary: Color
    var textTertiary: Color
    var glassBorder: Color
    var glassBorderActive: Color
    var sessionGradientTop: Color
    var sessionGradientBottom: Color
    /// Card back bottom-sheet base (frosted panel).
    var panelGlassBase: Color
    /// Subtle brand tint at top of panel gradient.
    var panelTintTop: Color

    static func palette(for scheme: ColorScheme) -> SemanticPalette {
        switch scheme {
        case .light: return .light
        case .dark: return .dark
        @unknown default: return .dark
        }
    }

    static let light = SemanticPalette(
        inkBlack: Color(hex: "#F8FAFC"),
        deepNavy: Color(hex: "#EFF3F8"),
        surfaceCard: Color(hex: "#FFFFFF"),
        moonPearl: Color(hex: "#0F172A"),
        textSecondary: Color(hex: "#334155"),
        textTertiary: Color(hex: "#64748B"),
        glassBorder: Color(white: 0, opacity: 0.07),
        glassBorderActive: Color(white: 0, opacity: 0.12),
        sessionGradientTop: Color(hex: "#E2E8F0"),
        sessionGradientBottom: Color(hex: "#F8FAFC"),
        panelGlassBase: Color(hex: "#FFFFFF").opacity(0.96),
        panelTintTop: Color(hex: "#007AFF").opacity(0.07)
    )

    /// Primary dark look (replaces separate “Night Blue” / “Midnight” palettes).
    static let dark = SemanticPalette(
        inkBlack: Color(hex: "#08080F"),
        deepNavy: Color(hex: "#0F1629"),
        surfaceCard: Color(hex: "#141B2D"),
        moonPearl: Color(hex: "#F1F5F9"),
        textSecondary: Color(hex: "#CBD5E1"),
        textTertiary: Color(hex: "#94A3B8"),
        glassBorder: Color(white: 1, opacity: 0.07),
        glassBorderActive: Color(white: 1, opacity: 0.14),
        sessionGradientTop: Color(hex: "#0F1629"),
        sessionGradientBottom: Color(hex: "#08080F"),
        panelGlassBase: Color(hex: "#0D1526").opacity(0.97),
        panelTintTop: Color(hex: "#007AFF").opacity(0.07)
    )
}

// MARK: - Legacy `AppTheme` raw values (migration only)

enum LegacyAppTheme: String {
    case nightBlue = "Night Blue"
    case midnight = "Midnight"
    case light = "Light"
}

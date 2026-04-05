import SwiftUI

// MARK: - Theme-aware semantic colors (see ThemeManager + SemanticPalette)

extension Color {
    // Backgrounds — follow effective light/dark palette
    static var inkBlack: Color { ThemeManager.shared.palette.inkBlack }
    static var deepNavy: Color { ThemeManager.shared.palette.deepNavy }
    static var surfaceCard: Color { ThemeManager.shared.palette.surfaceCard }
    static var panelGlassBase: Color { ThemeManager.shared.palette.panelGlassBase }
    static var panelTintTop: Color { ThemeManager.shared.palette.panelTintTop }
    static var sessionGradientTop: Color { ThemeManager.shared.palette.sessionGradientTop }
    static var sessionGradientBottom: Color { ThemeManager.shared.palette.sessionGradientBottom }

    // Brand — aligned with iOS system blue / Xcode chrome (sRGB; fixed across themes)
    static let cobaltBlue   = Color(hex: "#007AFF")
    static let skyBlue      = Color(hex: "#5AC8FA")
    static let navyBlue     = Color(hex: "#0040DD")

    // Semantic
    static let amberGlow    = Color(hex: "#F59E0B")
    static let amberDeep    = Color(hex: "#FF6B00")
    static let jadeGreen    = Color(hex: "#059669")
    static let coralRed     = Color(hex: "#F43F5E")
    static let dustGold     = Color(hex: "#D97706")

    // Text — theme-aware
    static var moonPearl: Color { ThemeManager.shared.palette.moonPearl }
    static var textSecondary: Color { ThemeManager.shared.palette.textSecondary }
    static var textTertiary: Color { ThemeManager.shared.palette.textTertiary }
    static let ashSlate     = Color(hex: "#64748B")
    static let dimGray      = Color(hex: "#334155")

    // Borders — theme-aware
    static var glassBorder: Color { ThemeManager.shared.palette.glassBorder }
    static var glassBorderActive: Color { ThemeManager.shared.palette.glassBorderActive }

    static let heroGradient: [Color] = [.cobaltBlue, .navyBlue, .skyBlue]
    static let streakGradient: [Color] = [.amberGlow, .amberDeep]
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradient Definitions

extension LinearGradient {
    /// Xcode-style vertical blue (bright top → deep bottom); used for CTAs, orbs, and text accents.
    static var hero: LinearGradient {
        LinearGradient(
            colors: [.cobaltBlue, .navyBlue],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static var heroVertical: LinearGradient {
        LinearGradient(
            colors: [.cobaltBlue, .navyBlue],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Theme-aware session background (review, summary, recap roots).
    static var session: LinearGradient {
        let p = ThemeManager.shared.palette
        return LinearGradient(
            colors: [p.sessionGradientTop, p.sessionGradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static let streak = LinearGradient(
        colors: [.amberGlow, .amberDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let jade = LinearGradient(
        colors: [Color(hex: "#059669"), Color(hex: "#047857")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let coral = LinearGradient(
        colors: [Color(hex: "#F43F5E"), Color(hex: "#BE123C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gold = LinearGradient(
        colors: [Color(hex: "#D97706"), Color(hex: "#B45309")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

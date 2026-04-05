import SwiftUI

// MARK: - Typography

extension Font {
    // Display
    static let lexisDisplay1 = Font.system(size: 38, weight: .bold, design: .default)
    static let lexisDisplay2 = Font.system(size: 30, weight: .bold, design: .default)
    static let lexisDisplay3 = Font.system(size: 24, weight: .semibold, design: .default)

    // Headings
    static let lexisH1 = Font.system(size: 22, weight: .semibold, design: .default)
    static let lexisH2 = Font.system(size: 18, weight: .semibold, design: .default)
    static let lexisH3 = Font.system(size: 16, weight: .medium, design: .default)

    // Body
    static let lexisBody   = Font.system(size: 15, weight: .regular, design: .default)
    static let lexisBodyM  = Font.system(size: 15, weight: .medium, design: .default)
    static let lexisBodySm = Font.system(size: 13, weight: .regular, design: .default)

    // Caption
    static let lexisCaption  = Font.system(size: 12, weight: .regular, design: .default)
    static let lexisCaptionM = Font.system(size: 12, weight: .medium, design: .default)

    // Mono (for phonetics)
    static let lexisMono   = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let lexisMonoSm = Font.system(size: 12, weight: .regular, design: .monospaced)
}

// MARK: - Text Modifier Shorthand

extension Text {
    func lexisStyle(_ font: Font, color: Color = .moonPearl) -> Text {
        self.font(font).foregroundColor(color)
    }
}

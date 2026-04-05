import SwiftUI
import UIKit

// MARK: - Session chrome (single source of truth for review header height)

enum SessionChromeMetrics {
    static let rowHeight: CGFloat = 40
    static let progressBarHeight: CGFloat = 4
    static let closeButtonSize: CGFloat = 32
    static let rowTopPadding: CGFloat = 6
    static let rowBottomPadding: CGFloat = 4

    /// Single-row height (no safe area).
    static var innerChromeHeight: CGFloat {
        rowTopPadding + rowHeight + rowBottomPadding
    }

    static func totalTopInset(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + innerChromeHeight
    }
}

// MARK: - Recap header reserve

enum RecapChromeMetrics {
    static func headerBlockHeight(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + 8 + 52 + 12
    }

    static let pageIndicatorReserve: CGFloat = 32
}

// MARK: - Bounded UIImage (aspect fit, letterbox, optional Ken Burns)

struct LexisBoundedImageView: View {
    let uiImage: UIImage?
    let loadFailed: Bool
    let initialLetter: String
    let viewport: CGSize
    var kenBurnsActive: Bool = false
    var reduceMotion: Bool = false

    private var kenScale: CGFloat {
        if reduceMotion { return 1.0 }
        return kenBurnsActive ? 1.03 : 1.0
    }

    private var kenOffset: CGSize {
        if reduceMotion { return .zero }
        return kenBurnsActive ? CGSize(width: 2, height: -2) : CGSize(width: -2, height: 2)
    }

    var body: some View {
        ZStack {
            // Retained as loading-state background; invisible once image fills viewport
            letterboxFill
                .frame(width: viewport.width, height: viewport.height)

            if let ui = uiImage {
                Group {
                    if reduceMotion {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewport.width, height: viewport.height)
                    } else {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewport.width, height: viewport.height)
                            .scaleEffect(kenScale)
                            .offset(kenOffset)
                            .animation(
                                .easeInOut(duration: 28).repeatForever(autoreverses: true),
                                value: kenBurnsActive
                            )
                    }
                }
            } else if loadFailed {
                placeholderLayer
            } else {
                ZStack {
                    placeholderLayer
                    ProgressView()
                        .tint(.textTertiary)
                }
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
    }

    private var letterboxFill: some View {
        LinearGradient(
            colors: [Color.deepNavy, Color.navyBlue.opacity(0.85)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var placeholderLayer: some View {
        ZStack {
            LinearGradient(
                colors: [Color.navyBlue.opacity(0.55), Color.cobaltBlue.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initialLetter)
                .font(.system(size: min(112, viewport.width * 0.28), weight: .black))
                .foregroundColor(.white.opacity(0.07))
        }
    }
}

// MARK: - Bounded AsyncImage (recap & simple URL loads)

struct LexisBoundedAsyncImage: View {
    let url: URL?
    let initialLetter: String
    let viewport: CGSize

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.deepNavy, Color.navyBlue.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: viewport.width, height: viewport.height)

            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewport.width, height: viewport.height)
                    case .failure:
                        placeholderLetter
                    default:
                        ZStack {
                            placeholderLetter.opacity(0.5)
                            ProgressView()
                                .tint(.textTertiary)
                        }
                    }
                }
            } else {
                placeholderLetter
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipped()
    }

    private var placeholderLetter: some View {
        ZStack {
            LinearGradient(
                colors: [Color.navyBlue.opacity(0.55), Color.cobaltBlue.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(initialLetter)
                .font(.system(size: min(112, viewport.width * 0.28), weight: .black))
                .foregroundColor(.white.opacity(0.07))
        }
    }
}

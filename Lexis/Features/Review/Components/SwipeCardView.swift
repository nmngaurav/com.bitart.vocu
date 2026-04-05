import SwiftUI

struct SwipeCardView: View {
    let card: ReviewQueueCard
    let isRevealed: Bool
    let viewport: CGSize
    let dragOffset: CGSize
    let dragRotation: Double
    let onToggleReveal: () -> Void
    let onDrag: (CGSize) -> Void
    let onDragEnd: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardCorner: CGFloat = 22

    private var dragBoost: CGFloat {
        guard !reduceMotion, isRevealed else { return 0 }
        return min(0.22, abs(dragOffset.width) / 420)
    }

    var body: some View {
        ZStack {
            RevealableCardView(
                card: card,
                isRevealed: isRevealed,
                viewport: viewport,
                onToggleReveal: onToggleReveal
            )

            if isRevealed, dragOffset.width < -40 {
                HStack {
                    swipeLabel("RATE", color: .cobaltBlue, icon: "star.circle.fill")
                        .padding(.leading, Spacing.xl)
                        .opacity(min(1.0, Double((-dragOffset.width - 40) / 80)))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
        }
        .frame(width: viewport.width, height: viewport.height)
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .shadow(
            color: .black.opacity(0.28 + dragBoost),
            radius: 20 + abs(dragOffset.width) * 0.04,
            x: dragOffset.width * 0.05,
            y: 12 + abs(dragOffset.width) * 0.02
        )
        .offset(dragOffset)
        .rotationEffect(.degrees(dragRotation))
        .simultaneousGesture(swipeGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                guard isRevealed else { return }
                onDrag(v.translation)
            }
            .onEnded { _ in
                guard isRevealed else { return }
                onDragEnd()
            }
    }

    private func swipeLabel(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(color)
                .tracking(1.5)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(color.opacity(0.4), lineWidth: 1.5))
    }
}

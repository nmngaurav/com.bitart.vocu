import SwiftUI

// MARK: - Glass Card Surface

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Spacing.lg
    var cornerRadius: CGFloat = Radius.lg

    init(
        padding: CGFloat = Spacing.lg,
        cornerRadius: CGFloat = Radius.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.glassBorder, lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    GlassCard {
        Text("Hello Lexis")
            .foregroundColor(.moonPearl)
    }
    .padding()
    .background(Color.inkBlack)
}

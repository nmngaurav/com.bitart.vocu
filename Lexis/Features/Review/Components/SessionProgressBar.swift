import SwiftUI

struct SessionProgressBar: View {
    let progress: Double   // 0.0 → 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Radius.pill)
                    .fill(Color.textTertiary.opacity(0.22))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: Radius.pill)
                    .fill(LinearGradient.hero)
                    .frame(width: max(8, geo.size.width * progress), height: 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 4)
    }
}

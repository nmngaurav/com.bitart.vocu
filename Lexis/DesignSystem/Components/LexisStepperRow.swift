import SwiftUI

/// Compact minus / value / plus control for numeric preferences (replaces system `Stepper` for premium styling).
struct LexisStepperRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var unitSuffix: String = ""

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundColor(.cobaltBlue)
            Text(title)
                .font(.lexisBodyM)
                .foregroundColor(.moonPearl)
            Spacer()

            HStack(spacing: Spacing.sm) {
                stepButton(delta: -step, enabled: value > range.lowerBound)

                Text("\(value)\(unitSuffix.isEmpty ? "" : " \(unitSuffix)")")
                    .font(.lexisBodyM)
                    .foregroundColor(.cobaltBlue)
                    .monospacedDigit()
                    .frame(minWidth: 72)

                stepButton(delta: step, enabled: value < range.upperBound)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
    }

    private func stepButton(delta: Int, enabled: Bool) -> some View {
        Button {
            guard enabled else { return }
            Haptics.impact(.light)
            let next = value + delta
            value = min(range.upperBound, max(range.lowerBound, next))
        } label: {
            Image(systemName: delta < 0 ? "minus" : "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(enabled ? .moonPearl : .textTertiary)
                .frame(width: 36, height: 36)
                .background(Color.glassBorder.opacity(enabled ? 1 : 0.4))
                .clipShape(Circle())
        }
        .disabled(!enabled)
    }
}

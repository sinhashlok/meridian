import SwiftUI

/// A round symbol button, 44pt or larger (DayPager chevrons, timer controls). The circle
/// grows with the text size up to AX1, then stops so rows still fit; a long press shows
/// it large (Large Content Viewer).
struct RoundIconButton: View {
    let systemImage: String
    let label: String
    var fill: Color = .bgSurface
    /// Diameter at the default text size.
    var size: CGFloat = Spacing.minTapTarget
    let action: () -> Void

    var body: some View {
        // The cap must sit outside the view that reads @ScaledMetric: a scaled metric
        // follows the text size of its surroundings, not limits set inside its own body.
        Circle(systemImage: systemImage, fill: fill, size: size, action: action)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityLabel(label)
            .accessibilityShowsLargeContentViewer {
                Label(label, systemImage: systemImage)
            }
    }

    private struct Circle: View {
        let systemImage: String
        let fill: Color
        let size: CGFloat
        let action: () -> Void

        @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

        var body: some View {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .frame(width: size * scale, height: size * scale)
                    .background(fill, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
        }
    }
}

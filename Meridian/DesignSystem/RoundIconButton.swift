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
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityLabel(label)
        .accessibilityShowsLargeContentViewer {
            Label(label, systemImage: systemImage)
        }
    }
}

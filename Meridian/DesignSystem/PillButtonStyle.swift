import SwiftUI

/// The neutral filled capsule for secondary actions (Today, +1 min, Copy CSV, a problem's
/// fix): `bgElevated`, headline, at least 44pt tall. Pressed = `fillControl` (§3.4: 120ms).
/// Use as `.buttonStyle(.pill)`.
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .meridianFont(.headline)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: Spacing.minTapTarget)
            .background(configuration.isPressed ? Color.fillControl : Color.bgElevated, in: .capsule)
            .contentShape(.capsule)
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
}

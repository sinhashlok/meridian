import SwiftUI

/// A list's summary line and its one filled orange button (spec §3.2): "2 running ·
/// New timer", "Next: 18:30 IST today · New alarm". One row; stacked at large text sizes.
struct ActionHeader<Summary: View>: View {
    let buttonTitle: String
    let action: () -> Void
    @ViewBuilder let summary: () -> Summary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) {
                summary().fixedSize()
                Spacer(minLength: 0)
                button.fixedSize()
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                button
                summary()
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var button: some View {
        Button(action: action) {
            Label(buttonTitle, systemImage: "plus")
                .meridianFont(.headline)
                .foregroundStyle(.onAccent)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.xs)
                .frame(minHeight: Spacing.minTapTarget)
                .background(.accent, in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

extension ActionHeader where Summary == AnyView {
    /// A plain secondary-text summary.
    init(_ summary: String?, buttonTitle: String, action: @escaping () -> Void) {
        self.init(buttonTitle: buttonTitle, action: action) {
            AnyView(Text(summary ?? "").meridianFont(.sub).foregroundStyle(.textSecondary))
        }
    }
}

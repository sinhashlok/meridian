import SwiftUI

/// A neutral note in the flow of the screen: title, optional detail and an optional
/// outlined button ("No hour works for all 3 cities", the clock-change warning).
/// Not an error, so no danger colour (spec principle 2: honest, never silent).
struct InlineBanner: View {
    let title: String
    var detail: String?
    var systemImage = "exclamationmark.circle"
    var action: (title: String, perform: () -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: systemImage)
                .meridianFont(.headline)
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                if let detail {
                    Text(detail)
                        .meridianFont(.body)
                        .foregroundStyle(.textSecondary)
                }
                if let action {
                    Button(action: action.perform) {
                        Text(action.title)
                            .meridianFont(.headline)
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: Spacing.minTapTarget)
                            .overlay { Capsule().strokeBorder(Color.fillControl, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .background(.bgElevated, in: .rect(cornerRadius: Radius.card, style: .continuous))
    }
}

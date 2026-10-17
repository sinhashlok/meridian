import SwiftUI

/// An info line in the flow of a screen: symbol, optional bold lead, then the text in
/// `textSecondary`. With `clock.arrow.circlepath` it is the spec's DSTNote (§5.1).
struct NoteLine: View {
    var systemImage = "info.circle"
    var lead: String?
    let text: String
    /// Side inset so the symbol lines up with card content; 0 inside a card.
    var inset: CGFloat = Spacing.xs

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: systemImage)
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            if let lead {
                Text("\(Text(lead).bold().foregroundStyle(.textPrimary)) \(text)")
                    .foregroundStyle(.textSecondary)
            } else {
                Text(text).foregroundStyle(.textSecondary)
            }
        }
        .meridianFont(.body)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, inset)
    }
}

import SwiftUI

/// `↺ DST in 8d` (spec §4.1): an outlined chip. Informational, so never orange (§3.2).
/// Tapping it opens Upcoming clock changes (§5.1).
struct DSTBadge: View {
    let text: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "clock.arrow.circlepath")
            Text(text)
        }
            .meridianFont(.caption).bold()
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .fixedSize()
            .overlay {
                RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    .strokeBorder(Color.textSecondary, lineWidth: 1)
            }
            // Invisible padding grows the tap target to about 44pt without moving the badge.
            .padding(.vertical, Spacing.s)
            .contentShape(.rect)
            .padding(.vertical, -Spacing.s)
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows upcoming clock changes")
    }
}

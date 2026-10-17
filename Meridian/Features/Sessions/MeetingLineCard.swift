import MeridianCore
import SwiftUI

/// The Sessions meeting line (spec §4.5, decision AY, board Sessions): globe, `Best
/// compromise in 21 min`, `16:00 UTC · 3 of 3 awake · Mumbai in stretch`, chevron.
/// Tapping opens Zones › Planner on that window.
struct MeetingLineCard: View {
    let line: MeetingLine
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: Spacing.s) {
                // Globe and chevron are decorative (the card is the button); dropped at
                // accessibility sizes so the words get the width.
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "globe")
                        .meridianFont(.headline)
                        .foregroundStyle(.textSecondary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.title)
                        .meridianFont(.headline)
                        .foregroundStyle(.textPrimary)
                    if let detail = line.detail {
                        Text(detail)
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if line.start != nil, !typeSize.isAccessibilitySize {
                    Image(systemName: "chevron.right")
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, minHeight: Spacing.minRowHeight, alignment: .leading)
            .background(.bgSurface, in: .rect(cornerRadius: Radius.card, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(line.start == nil)
        .accessibilityElement(children: .combine)
        .accessibilityHint(line.start == nil ? "" : "Opens the Planner at this time")
    }
}

import MeridianCore
import SwiftUI

/// DayPager (spec §4.1): previous · date + `W42 · day 288 · label` · next · Today.
struct DayPager: View {
    let text: DayPagerText
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Previous day")

            VStack(spacing: 2) {
                Text(text.title)
                    .meridianFont(.headline)
                    .foregroundStyle(.textPrimary)
                Text("\(text.caption) · \(text.label)")
                    .meridianFont(.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Next day")

            if !isToday {
                Button("Today", action: onToday)
                    .buttonStyle(.bordered)
                    .frame(minHeight: Spacing.minTapTarget)
            }
        }
        .tint(.accentText)
    }
}

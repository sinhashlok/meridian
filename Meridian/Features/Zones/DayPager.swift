import MeridianCore
import SwiftUI

/// DayPager (spec §4.1): previous · date, `W42 · day 288`, label · next · Today.
/// On today the label is dropped and Today is dimmed (decision Q), so the row never jumps.
struct DayPager: View {
    let text: DayPagerText
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // At accessibility sizes the date gets the full width and the buttons go below it.
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Spacing.s) {
                dateText
                HStack(spacing: Spacing.xs) { previous; next; Spacer(minLength: 0); today }
            }
        } else {
            HStack(spacing: Spacing.xs) {
                previous
                dateText.frame(maxWidth: .infinity)
                next
                today
            }
        }
    }

    private var previous: some View {
        RoundIconButton(systemImage: "chevron.left", label: "Previous day", action: onPrevious)
    }

    private var next: some View {
        RoundIconButton(systemImage: "chevron.right", label: "Next day", action: onNext)
    }

    private var dateText: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text(text.title)
                .meridianFont(.title)
                .foregroundStyle(.textPrimary)
            Text(text.caption)
                .meridianFont(.monoCaption)
                .foregroundStyle(.textSecondary)
            if !isToday || text.label != "Today" {
                Text(text.label)
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
        }
        .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var today: some View {
        Button(action: onToday) {
            Text("Today")
                .meridianFont(.headline)
                .foregroundStyle(isToday ? Color.textTertiary : Color.textPrimary)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Spacing.minTapTarget)
                .background(isToday ? Color.clear : Color.bgElevated, in: .capsule)
                .overlay { Capsule().strokeBorder(isToday ? Color.separatorLine : .clear, lineWidth: 1) }
                .fixedSize()
        }
        .buttonStyle(.plain)
        .disabled(isToday)
    }
}

/// A neutral 44pt circle with a symbol (DayPager chevrons).
struct RoundIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
                .frame(width: Spacing.minTapTarget, height: Spacing.minTapTarget)
                .background(.bgSurface, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

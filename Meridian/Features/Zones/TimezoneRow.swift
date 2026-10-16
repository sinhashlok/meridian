import MeridianCore
import SwiftUI

/// TimezoneRow (.clock), spec §4.1: day offset, city, `BST (UTC+1)` with a DSTBadge when a
/// change is within 14 days, and the time. Stacks vertically at large text sizes.
struct TimezoneRow: View {
    let saved: SavedZone
    let home: Zone?
    let now: Date
    let onShowChanges: () -> Void

    var body: some View {
        if let zone = saved.zone {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Spacing.s) {
                    details(zone)
                    Spacer(minLength: Spacing.s)
                    time(zone)
                }
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    details(zone)
                    time(zone)
                }
            }
            .frame(minHeight: Spacing.minRowHeight)
            // Separators start at the row's edge, not at whichever text comes first.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Upcoming clock changes", onShowChanges)
        } else {
            Label("\(saved.name): \(saved.ianaID) is no longer a known zone", systemImage: "exclamationmark.triangle")
                .meridianFont(.sub)
                .foregroundStyle(.statusDanger)
        }
    }

    private func details(_ zone: Zone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(saved.isHome ? "Home" : ZoneClock.dayOffsetText(zone, relativeTo: home ?? zone, at: now))
                .meridianFont(.caption)
                .foregroundStyle(.textSecondary)
            Text(saved.name)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
            Text(ZoneClock.label(zone, at: now))
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
            if let badge = ZoneClock.dstBadgeText(zone, now: now) {
                DSTBadge(text: badge, action: onShowChanges)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func time(_ zone: Zone) -> some View {
        Text(ZoneClock.wallTime(now, in: zone))
            .meridianFont(.timeRow)
            .foregroundStyle(.textPrimary)
            .contentTransition(.numericText())
    }
}

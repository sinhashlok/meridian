import MeridianCore
import SwiftUI

/// TimezoneRow (.clock), spec §4.1 and board ClocksBanner: city (house for home) with a
/// DSTBadge when a change is within 14 days, then `BST (UTC+1) · Today · −4h 30m`, and
/// the time. Stacks vertically at large text sizes.
struct TimezoneRow: View {
    let saved: SavedZone
    let home: Zone?
    let now: Date
    let onShowChanges: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if let zone = saved.zone {
            // ViewThatFits would judge the details unwrapped and stack too early; at regular
            // sizes they wrap beside the time instead.
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        details(zone)
                        time(zone)
                    }
                } else {
                    HStack(alignment: .center, spacing: Spacing.s) {
                        details(zone)
                        Spacer(minLength: 0)
                        time(zone).fixedSize()
                    }
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
        let badge = ZoneClock.dstBadgeText(zone, now: now)
        let relation = saved.isHome ? "Home" : ZoneClock.dayOffsetText(zone, relativeTo: home ?? zone, at: now)
        return VStack(alignment: .leading, spacing: 2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) {
                    name
                    if let badge { DSTBadge(text: badge, action: onShowChanges) }
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    name
                    if let badge { DSTBadge(text: badge, action: onShowChanges) }
                }
            }
            Text("\(ZoneClock.label(zone, at: now)) · \(relation)")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var name: some View {
        HStack(spacing: Spacing.xxs) {
            if saved.isHome {
                Image(systemName: "house.fill")
                    .meridianFont(.caption)
                    .foregroundStyle(.textSecondary)
            }
            Text(saved.name)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
        }
    }

    private func time(_ zone: Zone) -> some View {
        Text(ZoneClock.wallTime(now, in: zone))
            .meridianFont(.timeRow)
            .foregroundStyle(.textPrimary)
            .numericTransition()
    }
}

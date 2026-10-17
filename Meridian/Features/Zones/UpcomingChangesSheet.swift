import MeridianCore
import SwiftUI

/// Upcoming clock changes (spec §5.1, board ClockChanges), opened from a DSTBadge or the
/// Clocks banner: each saved zone's next change, soonest first (decision S), plus the
/// zones alarms and jobs use (decision BJ).
struct UpcomingChangesSheet: View {
    let zones: [SavedZone]
    /// Zones of alarms and jobs, shown after saved zones that aren't already there.
    var alsoUsed: [(zone: Zone, name: String)] = []

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let now = appState.now()
        let saved = zones.compactMap(\.named)
        let extra = alsoUsed.filter { used in !saved.contains { $0.zone == used.zone } }
        let cards = ZoneClock.changeCards(for: saved + extra, now: now, device: Zone.device)

        NavigationStack {
            List {
                Section {
                    ForEach(cards, id: \.name) { card in
                        ChangeCardRow(card: card)
                            .listRowBackground(Color.bgSurface)
                    }
                } header: {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        Text("Next change in each zone you use, soonest first. Times on this phone are "
                             + "\(ZoneClock.label(Zone.device, at: now)).")
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                            .textCase(nil)
                        Text(alsoUsed.isEmpty ? "Your zones" : "Your zones, alarms and jobs")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Upcoming clock changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
    }
}

/// `London  ↺ Back 1 hour` / `Sun 25 Oct 2026 · 02:00 BST → 01:00 GMT  UTC+0` /
/// `06:30 IST on this phone · in 9 days`. Stacks at accessibility sizes.
private struct ChangeCardRow: View {
    let card: ClockChangeCard

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.xxs) { details; summary(alignment: .leading) }
            } else {
                HStack(alignment: .top, spacing: Spacing.s) {
                    details
                    Spacer(minLength: 0)
                    summary(alignment: .trailing).fixedSize()
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .frame(minHeight: Spacing.minRowHeight, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(card.name)
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
            Text(card.detail)
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
            if let phone = card.phone {
                Text(phone)
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summary(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: Spacing.xxs) {
            if card.instant != nil {
                // Not a Label: inside a List row a fixed-size Label drops its title.
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(card.headline)
                }
                .meridianFont(.headline)
                .foregroundStyle(.textPrimary)
            } else {
                Text(card.headline)
                    .meridianFont(.sub)
                    .foregroundStyle(.textSecondary)
            }
            Text(card.offset)
                .meridianFont(.monoCaption)
                .foregroundStyle(.textSecondary)
        }
    }
}

import MeridianCore
import SwiftUI

/// Upcoming clock changes for the saved zones (spec §5.1), opened from a DSTBadge.
struct UpcomingChangesSheet: View {
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // One entry per zone id; the first saved name labels it.
        var names: [String: String] = [:]
        for saved in zones where names[saved.ianaID] == nil { names[saved.ianaID] = saved.name }
        let unique = names.keys.compactMap(Zone.init)
        let now = appState.now()
        let changes = ZoneClock.upcomingChanges(in: unique, after: now, limit: 12)
        let thisYear = ZoneClock.local(now, in: .utc).date.year

        return NavigationStack {
            List {
                if changes.isEmpty {
                    ContentUnavailableView("No clock changes", systemImage: "clock",
                                           description: Text("None of your zones change their clocks in the next two years."))
                        .listRowBackground(Color.clear)
                }
                ForEach(changes, id: \.transition.instant) { change in
                    let date = ZoneClock.local(change.transition.instant, in: change.zone).date
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(names[change.zone.id] ?? change.zone.cityName) · " + date.shortText
                             + (date.year == thisYear ? "" : " \(date.year)"))
                            .meridianFont(.headline)
                            .foregroundStyle(.textPrimary)
                        Text("\(change.transition.before.label) → \(change.transition.after.label)")
                            .meridianFont(.sub)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(minHeight: Spacing.minRowHeight, alignment: .leading)
                    .listRowBackground(Color.bgSurface)
                    .accessibilityElement(children: .combine)
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

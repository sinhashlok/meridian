import MeridianCore
import SwiftData
import SwiftUI

/// Edit a saved zone: name, work hours and days (spec §4.1: editable per zone), home,
/// remove. Changes save as you go.
struct ZoneEditSheet: View {
    @Bindable var zone: SavedZone
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $zone.name)
                } header: {
                    Text("Name")
                } footer: {
                    Text(zone.ianaID)
                }
                .listRowBackground(Color.bgSurface)

                Section {
                    ClockTimePicker(title: "Starts", time: Binding(
                        get: { zone.workStart }, set: { zone.workStartMinutes = $0.minutesAfterMidnight }))
                    ClockTimePicker(title: "Ends", time: Binding(
                        get: { zone.workEnd }, set: { zone.workEndMinutes = $0.minutesAfterMidnight }))
                } header: {
                    Text("Work hours")
                } footer: {
                    if zone.workStart < zone.workEnd {
                        Text("Stretch hours are the 2 hours before and 4 hours after.")
                    } else {
                        Label("Work hours must end after they start, on the same day.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.statusDanger)
                    }
                }
                .listRowBackground(Color.bgSurface)

                Section("Work days") {
                    WeekdayPicker(days: $zone.workDays, first: appState.firstWeekday)
                }
                .listRowBackground(Color.bgSurface)

                Section {
                    if zone.isHome {
                        Label("Home zone", systemImage: "house.fill")
                            .foregroundStyle(.textPrimary)
                    } else {
                        Button("Make home zone") { ZoneStore.makeHome(zone, among: zones) }
                    }
                } footer: {
                    Text("The Planner's day and the Clocks offsets follow the home zone.")
                }
                .listRowBackground(Color.bgSurface)

                Section {
                    Button("Remove zone", role: .destructive) {
                        ZoneStore.delete(zone, from: zones, in: context)
                        dismiss()
                    }
                }
                .listRowBackground(Color.bgSurface)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(zone.name.isEmpty ? "Zone" : zone.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
        .onDisappear {
            // A blank name falls back to the zone's catalog name.
            if !zone.isDeleted, zone.name.trimmingCharacters(in: .whitespaces).isEmpty, let saved = zone.zone {
                zone.name = ZoneCatalog.displayName(for: saved)
            }
        }
    }
}

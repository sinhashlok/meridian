import MeridianCore
import SwiftData
import SwiftUI

/// Add zone: native search by city, country, abbreviation or offset (spec §4.1).
/// An empty search shows the suggestions.
struct AddZoneSheet: View {
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let now = appState.now()
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Suggestions") {
                        ForEach(ZoneCatalog.suggestions, id: \.self) { entry in
                            row(name: entry.city, detail: "\(entry.country) · \(ZoneClock.label(entry.zone, at: now))",
                                zone: entry.zone)
                        }
                    }
                } else {
                    let results = ZoneCatalog.search(query, at: now)
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(results, id: \.self) { result in
                        row(name: result.name, detail: result.detail, zone: result.zone)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "City, country, BST or +5:30")
            .navigationTitle("Add zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
    }

    private func row(name: String, detail: String, zone: Zone) -> some View {
        let isAdded = ZoneStore.contains(zone, named: name, in: zones)
        return Button {
            ZoneStore.add(zone, named: name, to: zones, in: context, defaults: appState.zoneDefaults)
            dismiss()
        } label: {
            HStack(spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .meridianFont(.headline)
                        .foregroundStyle(.textPrimary)
                    Text(detail)
                        .meridianFont(.sub)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: Spacing.s)
                if isAdded {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.textSecondary)
                        .accessibilityLabel("Added")
                }
            }
            .frame(minHeight: Spacing.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
        .listRowBackground(Color.bgSurface)
    }
}

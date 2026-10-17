import MeridianCore
import SwiftData
import SwiftUI

/// The zone picker for alarms and jobs (spec §4.2, decision BI): Local (alarms only),
/// UTC, your saved zones, the last five picked, then search by city, country,
/// abbreviation or offset. `nil` means Local, the phone's own clock.
struct ZonePickerSheet: View {
    let title: String
    let allowsLocal: Bool
    let selected: String?
    let onPick: (Zone?) -> Void

    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    /// Comma-separated IANA ids, most recent first.
    @AppStorage("zonePicker.recents") private var recentIDs = ""
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let now = appState.now()
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        if allowsLocal {
                            row(name: "Local", detail: "This phone's clock, wherever it is", zone: nil)
                        }
                        row(name: "UTC", detail: "Never changes", zone: .utc)
                    }
                    let saved = zones.compactMap(\.named).filter { $0.zone != .utc }
                    if !saved.isEmpty {
                        Section("Your zones") {
                            ForEach(saved, id: \.zone) { item in
                                row(name: item.name, detail: ZoneClock.label(item.zone, at: now), zone: item.zone)
                            }
                        }
                    }
                    let recents = recentIDs.split(separator: ",").compactMap { Zone(String($0)) }
                        .filter { zone in zone != .utc && !saved.contains { $0.zone == zone } }
                    if !recents.isEmpty {
                        Section("Recent") {
                            ForEach(recents, id: \.self) { zone in
                                row(name: ZoneCatalog.displayName(for: zone), detail: ZoneClock.label(zone, at: now),
                                    zone: zone)
                            }
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationBackground(.bgElevated)
    }

    private func row(name: String, detail: String, zone: Zone?) -> some View {
        Button {
            if let zone { remember(zone) }
            onPick(zone)
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
                if zone?.id == selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.textSecondary)
                        .accessibilityLabel("Selected")
                }
            }
            .frame(minHeight: Spacing.minTapTarget)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.bgSurface)
    }

    private func remember(_ zone: Zone) {
        guard zone != .utc else { return }
        let ids = [zone.id] + recentIDs.split(separator: ",").map(String.init).filter { $0 != zone.id }
        recentIDs = ids.prefix(5).joined(separator: ",")
    }
}

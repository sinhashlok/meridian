import MeridianCore
import SwiftData
import SwiftUI

/// Zones › Clocks: the world clock list (spec §4.1). Times follow each zone, also in UTC
/// mode (decision I). Delete and reorder through the visible Edit button.
struct ClocksView: View {
    let zones: [SavedZone]

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @State private var editing: SavedZone?
    @State private var isAdding = false
    @State private var showsChanges = false

    private var home: Zone? { zones.first(where: \.isHome)?.zone }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            List {
                if appState.warnsBeforeClockChanges, let home,
                   let warning = ZoneClock.changeWarning(for: zones.compactMap(\.named), home: home, now: now) {
                    Section {
                        InlineBanner(title: warning.title, detail: warning.detail, systemImage: "clock.arrow.circlepath",
                                     action: ("All clock changes", { showsChanges = true }))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    ForEach(zones) { saved in
                        Button { editing = saved } label: {
                            TimezoneRow(saved: saved, home: home, now: now) { showsChanges = true }
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.bgSurface)
                    }
                    .onMove { ZoneStore.move(zones, from: $0, to: $1) }
                    .onDelete { offsets in
                        for saved in offsets.map({ zones[$0] }) { ZoneStore.delete(saved, from: zones, in: context) }
                    }
                } header: {
                    HStack {
                        Spacer()
                        EditButton()
                    }
                } footer: {
                    // A footer, not a row: List clips rows to its rounded section shape.
                    AddZoneButton { isAdding = true }
                        .padding(.top, Spacing.xs)
                        .padding(.horizontal, -Spacing.m)
                }

                if zones.count < 3 {
                    Section("Suggestions") {
                        ZoneSuggestions(zones: zones)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listSectionSpacing(Spacing.s)
            .contentMargins(.top, Spacing.xs, for: .scrollContent)
            .scrollContentBackground(.hidden)
            // Edit is orange text under 20pt: accent.text (§3.1).
            .tint(.accentText)
        }
        .sheet(isPresented: $isAdding) { AddZoneSheet(zones: zones) }
        .sheet(item: $editing) { ZoneEditSheet(zone: $0, zones: zones) }
        .sheet(isPresented: $showsChanges) { UpcomingChangesSheet(zones: zones) }
        .onAppear(perform: openDebugScreen)
    }

    private func openDebugScreen() {
        switch DebugLaunch.screen {
        case "addZone": isAdding = true
        case "editZone": editing = zones.first
        case "changes": showsChanges = true
        default: break
        }
    }
}

/// Suggestion chips (spec §2 first launch): London · New York · San Francisco ·
/// Singapore · UTC, minus any already added. Wraps instead of scrolling sideways.
struct ZoneSuggestions: View {
    let zones: [SavedZone]
    @Environment(\.modelContext) private var context

    var body: some View {
        let remaining = ZoneCatalog.suggestions.filter { !ZoneStore.contains($0.zone, named: $0.city, in: zones) }
        FlowLayout(spacing: Spacing.xs) {
            ForEach(remaining, id: \.self) { entry in
                Button {
                    ZoneStore.add(entry.zone, named: entry.city, to: zones, in: context)
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "plus")
                        Text(entry.city)
                    }
                    .meridianFont(.sub)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, Spacing.s)
                    .frame(minHeight: Spacing.minTapTarget)
                    .fixedSize()
                    .background(.bgElevated, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(entry.city)")
            }
        }
    }
}

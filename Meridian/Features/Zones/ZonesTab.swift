import MeridianCore
import SwiftData
import SwiftUI

enum ZonesSegment: String, CaseIterable, Identifiable {
    case planner, clocks

    var id: Self { self }

    var title: String {
        switch self {
        case .planner: "Planner"
        case .clocks: "Clocks"
        }
    }
}

struct ZonesTab: View {
    /// Remembered across launches (spec §2: each tab remembers its last segment).
    @AppStorage("zones.segment") private var segment: ZonesSegment = .planner
    /// Set once the device zone has been added, so deleting every zone doesn't re-add it.
    @AppStorage("zones.seeded") private var isSeeded = false
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("View", selection: $segment) {
                    ForEach(ZonesSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)
                .sensoryFeedback(Haptic.selection, trigger: segment)

                switch segment {
                case .planner:
                    ContentUnavailableView("Planner", systemImage: "chart.bar.xaxis", description: Text("Coming in M3 step 4"))
                case .clocks:
                    ClocksView(zones: zones)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: "Zones")
        }
        .task(prepareZones)
    }

    private func prepareZones() {
        if let debugZones = DebugLaunch.zones {
            for saved in zones { context.delete(saved) }
            for (index, entry) in debugZones.enumerated() {
                context.insert(SavedZone(ianaID: entry.zone.id, name: entry.name, isHome: index == 0, order: index))
            }
        } else if !isSeeded {
            if zones.isEmpty { ZoneStore.seed(into: context) }
            isSeeded = true
        }
        switch DebugLaunch.screen {
        case "planner": segment = .planner
        case "clocks", "addZone", "editZone", "changes": segment = .clocks
        default: break
        }
    }
}

#Preview {
    ZonesTab()
        .environment(AppState())
        .modelContainer(for: SavedZone.self, inMemory: true)
        .preferredColorScheme(.dark)
}

import MeridianCore
import SwiftData
import SwiftUI

enum ZonesSegment: String, ScreenSegment {
    case planner, clocks

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
    @Environment(AppState.self) private var appState

    var body: some View {
        SegmentedScreen(title: "Zones", segment: $segment) { segment in
            switch segment {
            case .planner: PlannerView(zones: zones)
            case .clocks: ClocksView(zones: zones)
            }
        }
        .task(prepareZones)
        // Sessions' meeting line asks for a Planner window.
        .onChange(of: appState.plannerJump) { _, jump in
            if jump != nil { segment = .planner }
        }
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
        case "planner", "plannerScrub": segment = .planner
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

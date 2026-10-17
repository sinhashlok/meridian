import SwiftData
import SwiftUI

enum ToolsSegment: String, ScreenSegment {
    case epoch, cron, dates

    var title: String {
        switch self {
        case .epoch: "Epoch"
        case .cron: "Cron"
        case .dates: "Dates"
        }
    }
}

struct ToolsTab: View {
    @AppStorage("tools.segment") private var segment: ToolsSegment = .epoch
    @Query(sort: \SavedFiscalProfile.order) private var fiscalProfiles: [SavedFiscalProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        SegmentedScreen(title: "Tools", segment: $segment) { segment in
            switch segment {
            case .epoch: EpochView()
            case .cron: CronView()
            case .dates: DatesView()
            }
        }
        .task {
            if let tool = DebugLaunch.tool.flatMap(ToolsSegment.init(rawValue:)) { segment = tool }
            FiscalStore.applyDebugLaunch(fiscalProfiles, in: context)
        }
    }
}

#Preview {
    ToolsTab()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

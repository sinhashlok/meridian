import SwiftData
import SwiftUI

enum ToolsSegment: String, CaseIterable, Identifiable {
    case epoch, cron, dates

    var id: Self { self }

    var title: String {
        switch self {
        case .epoch: "Epoch"
        case .cron: "Cron"
        case .dates: "Dates"
        }
    }

    var systemImage: String {
        switch self {
        case .epoch: "number"
        case .cron: "calendar.badge.clock"
        case .dates: "calendar"
        }
    }
}

struct ToolsTab: View {
    @AppStorage("tools.segment") private var segment: ToolsSegment = .epoch
    @Query(sort: \SavedFiscalProfile.order) private var fiscalProfiles: [SavedFiscalProfile]
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("Tool", selection: $segment) {
                    ForEach(ToolsSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)

                switch segment {
                case .epoch:
                    EpochView()
                case .cron:
                    CronView()
                case .dates:
                    ContentUnavailableView(segment.title, systemImage: segment.systemImage,
                                           description: Text("Coming in M4"))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: "Tools")
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

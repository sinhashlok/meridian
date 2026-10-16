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

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.m) {
                Picker("Tool", selection: $segment) {
                    ForEach(ToolsSegment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.screenMargin)

                ContentUnavailableView(
                    segment.title,
                    systemImage: segment.systemImage,
                    description: Text("Coming in M4")
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .meridianScreen(title: "Tools")
        }
    }
}

#Preview {
    ToolsTab()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

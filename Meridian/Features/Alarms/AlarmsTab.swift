import SwiftData
import SwiftUI

enum AlarmsSegment: String, ScreenSegment {
    case alarms, jobs

    var title: String {
        switch self {
        case .alarms: "Alarms"
        case .jobs: "Jobs"
        }
    }
}

struct AlarmsTab: View {
    @AppStorage("alarms.segment") private var segment: AlarmsSegment = .alarms

    var body: some View {
        SegmentedScreen(title: "Alarms", segment: $segment) { segment in
            switch segment {
            case .alarms: AlarmsView()
            case .jobs: JobsView()
            }
        }
    }
}

#Preview {
    AlarmsTab()
        .environment(AppState())
        .modelContainer(AppModel.preview)
        .preferredColorScheme(.dark)
}

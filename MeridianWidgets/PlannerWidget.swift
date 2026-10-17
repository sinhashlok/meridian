import MeridianCore
import SwiftUI
import WidgetKit

/// Medium Planner widget (board WidgetFull, decision BU): home and the next two zones, the
/// home day with the now-line, and the best window from now on. Opens Zones › Planner.
struct PlannerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlannerWidget", provider: SnapshotProvider()) { entry in
            PlannerWidgetView(text: WidgetText.planner(entry.snapshot, now: entry.date))
                .homeScreenBackground()
                .widgetURL(WidgetLink.planner)
        }
        .configurationDisplayName("Planner")
        .description("Your zones' day and the best time to meet.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview("Planner", as: .systemMedium) {
    PlannerWidget()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
    SnapshotEntry(date: DemoData.now, snapshot: .empty)
}

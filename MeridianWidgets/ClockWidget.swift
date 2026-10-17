import MeridianCore
import SwiftUI
import WidgetKit

/// Small clock widget (decision BT): UTC, then the home city. Opens Zones › Clocks.
struct ClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ClockWidget", provider: SnapshotProvider()) { entry in
            ClockWidgetView(text: WidgetText.clock(entry.snapshot, now: entry.date))
                .homeScreenBackground()
                .widgetURL(WidgetLink.clocks)
        }
        .configurationDisplayName("UTC and home")
        .description("UTC, with your home city's time and offset.")
        .supportedFamilies([.systemSmall])
    }
}

/// Lock Screen UTC (decision BW): `UTC 15:32` inline, or a circle. Opens Zones › Clocks.
struct UTCAccessory: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UTCAccessory", provider: SnapshotProvider()) { entry in
            UTCAccessoryView(entry: entry)
                .widgetURL(WidgetLink.clocks)
        }
        .configurationDisplayName("UTC")
        .description("The time in UTC.")
        .supportedFamilies([.accessoryInline, .accessoryCircular])
    }
}

private struct UTCAccessoryView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryCircular {
            UTCCircularView(text: WidgetText.clock(entry.snapshot, now: entry.date))
                .accessoryBackground(circular: true)
        } else {
            UTCInlineView(now: entry.date)
                .accessoryBackground(circular: false)
        }
    }
}

#Preview("Clock", as: .systemSmall) {
    ClockWidget()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

#Preview("UTC", as: .accessoryCircular) {
    UTCAccessory()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

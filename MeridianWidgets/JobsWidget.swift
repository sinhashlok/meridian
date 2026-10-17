import MeridianCore
import SwiftUI
import WidgetKit

/// Jobs widgets (boards JobsWidgetFull, JobsWidgetLarge, decision BW): the next runs in the
/// phone's zone, or UTC in UTC mode. Opens Alarms › Jobs.
struct JobsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JobsWidget", provider: SnapshotProvider()) { entry in
            JobsWidgetView(jobs: WidgetText.jobs(entry.snapshot, now: entry.date, device: .device))
                .homeScreenBackground()
                .widgetURL(WidgetLink.jobs)
        }
        .configurationDisplayName("Next jobs")
        .description("When your scheduled jobs run next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct JobsWidgetView: View {
    let jobs: JobsWidgetText
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall: JobsSmallView(jobs: jobs)
        case .systemLarge: JobsLargeView(jobs: jobs)
        default: JobsMediumView(jobs: jobs)
        }
    }
}

/// Lock Screen "Next job" (board JobsLockWidgets): inline, circular, rectangular.
struct NextJobAccessory: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextJobAccessory", provider: SnapshotProvider()) { entry in
            NextJobAccessoryView(jobs: WidgetText.jobs(entry.snapshot, now: entry.date, device: .device))
                .widgetURL(WidgetLink.jobs)
        }
        .configurationDisplayName("Next job")
        .description("Your next scheduled job and how soon it runs.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct NextJobAccessoryView: View {
    let jobs: JobsWidgetText
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            NextJobCircularView(jobs: jobs).accessoryBackground(circular: true)
        case .accessoryRectangular:
            NextJobRectangularView(jobs: jobs).accessoryBackground(circular: false)
        default:
            NextJobInlineView(jobs: jobs).accessoryBackground(circular: false)
        }
    }
}

#Preview("Jobs small", as: .systemSmall) {
    JobsWidget()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

#Preview("Jobs medium", as: .systemMedium) {
    JobsWidget()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

#Preview("Jobs large", as: .systemLarge) {
    JobsWidget()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

#Preview("Next job", as: .accessoryRectangular) {
    NextJobAccessory()
} timeline: {
    SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
}

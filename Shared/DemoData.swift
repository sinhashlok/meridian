import Foundation
import MeridianCore

/// The boards' zones and jobs (boards JobsList, WidgetFull, JobsWidget*), at the boards'
/// time. Used by debug `-MeridianJobs demo`, the widget gallery and Xcode previews, and the
/// widget picker's preview (a widget added before the app has written a snapshot).
enum DemoData {
    /// Thu 15 Oct 2026 15:32:07Z = 21:02 IST.
    static let now = Date(timeIntervalSince1970: 1_792_078_327)

    static let zones: [WidgetSnapshot.SavedZoneData] = [
        .init(ianaID: "Asia/Kolkata", name: "Mumbai", isHome: true),
        .init(ianaID: "Europe/London", name: "London", isHome: false),
        .init(ianaID: "America/Los_Angeles", name: "San Francisco", isHome: false),
    ]

    /// New ids on every call, like jobs the user adds.
    static var jobs: [Job] {
        [
            Job(title: "Marketing dashboard refresh", category: .dashboard, schedule: .everyHours(4),
                lastReviewed: CivilDate(2026, 10, 1)),
            Job(title: "Netsuite pipeline run",
                notes: "Loads NetSuite GL, AR and AP into the lakehouse each night, then rebuilds the sales views.",
                category: .pipeline, mirrors: "Airflow DAG netsuite_nightly",
                schedule: .daily(times: [ClockTime(2, 0)]), remindsMe: true, lastReviewed: CivilDate(2026, 7, 12),
                children: [Job.Child(name: "Bronze load", offsetMinutes: 0),
                           Job.Child(name: "Silver transform", offsetMinutes: 20),
                           Job.Child(name: "Gold views", offsetMinutes: 45),
                           Job.Child(name: "Sales dashboard refresh", offsetMinutes: 90)]),
            Job(title: "Month-end close extract", category: .extract,
                schedule: .monthly(day: .day(1), time: ClockTime(1, 0)), zoneID: "America/New_York",
                remindsMe: true, lastReviewed: CivilDate(2026, 9, 1)),
            Job(title: "Legacy CRM sync", category: .other, schedule: .weekly(days: [7], time: ClockTime(3, 0)),
                isPaused: true, lastReviewed: CivilDate(2026, 9, 1)),
        ]
    }

    static var snapshot: WidgetSnapshot { WidgetSnapshot(zones: zones, jobs: jobs) }
}

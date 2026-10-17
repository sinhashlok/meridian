import Foundation
import MeridianCore
import SwiftData

/// A saved job (spec §7 `Job`, decision BO): the Core `Job` as JSON, like `SavedTimer`.
@Model
final class SavedJob {
    var data: Data
    /// Creation order; the list itself is grouped and sorted by `JobText.groups`.
    var order: Int

    init(job: Job, order: Int) {
        self.data = (try? JSONEncoder().encode(job)) ?? Data()
        self.order = order
    }

    /// `nil` only if the stored JSON no longer decodes.
    var job: Job? {
        get { try? JSONDecoder().decode(Job.self, from: data) }
        set { if let newValue, let encoded = try? JSONEncoder().encode(newValue) { data = encoded } }
    }
}

/// Every change to saved jobs goes through here; callers then run
/// `JobReminders.shared.sync` so reminders match.
enum JobStore {
    static func jobs(from saved: [SavedJob]) -> [(row: SavedJob, job: Job)] {
        saved.compactMap { row in row.job.map { (row, $0) } }
    }

    static func add(_ job: Job, to saved: [SavedJob], in context: ModelContext) {
        context.insert(SavedJob(job: job, order: (saved.map(\.order).max() ?? -1) + 1))
    }

    static func update(_ row: SavedJob, _ change: (inout Job) -> Void) {
        guard var job = row.job else { return }
        change(&job)
        row.job = job
    }

    /// Mark reviewed: today on this phone (spec §4.3).
    static func markReviewed(_ row: SavedJob, now: Date) {
        update(row) { $0.lastReviewed = ZoneClock.local(now, in: .device).date }
    }

    static func delete(_ row: SavedJob, in context: ModelContext) {
        context.delete(row)
    }

    /// `-MeridianJobs demo`: board JobsList's four jobs; `none`: no jobs (board JobsEmpty).
    /// Each replaces any saved jobs.
    static func applyDebugLaunch(_ saved: [SavedJob], in context: ModelContext) {
        guard let mode = DebugLaunch.jobs, ["demo", "none"].contains(mode) else { return }
        for row in saved { context.delete(row) }
        guard mode == "demo" else { return }
        let jobs = [
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
        for (index, job) in jobs.enumerated() {
            context.insert(SavedJob(job: job, order: index))
        }
    }
}

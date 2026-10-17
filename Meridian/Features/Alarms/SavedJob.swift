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
        let jobs = DemoData.jobs
        for (index, job) in jobs.enumerated() {
            context.insert(SavedJob(job: job, order: index))
        }
    }
}

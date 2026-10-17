import Foundation

/// One local notification before a job's run (decision BK).
public struct JobReminder: Equatable, Sendable {
    /// `job-<job id>-<run epoch seconds>`: the same run always gets the same identifier.
    public let identifier: String
    public let jobID: UUID
    public let fireDate: Date
    public let run: Date
    /// `Netsuite pipeline run in 10 min`.
    public let title: String
    /// `Expected at 07:30 IST · Daily · 02:00 UTC`.
    public let body: String
}

/// Job reminders in a rolling window, refilled on every change, launch, return to the app
/// and background refresh (CLAUDE.md: iOS keeps at most 64 pending notifications).
public enum ReminderPlan {
    public static let window: TimeInterval = 48 * 3600
    /// Leaves 16 of iOS's 64 for timer and session fallback notifications.
    public static let budget = 48
    public static let prefix = "job-"

    /// Every reminder due in the next 48 hours for unpaused jobs with Remind me on,
    /// soonest first, at most `budget`.
    public static func wanted(_ jobs: [Job], now: Date, device: Zone) -> [JobReminder] {
        let end = now + window
        let all = jobs.filter { $0.remindsMe && !$0.isPaused }.flatMap { job in
            let lead = TimeInterval(job.reminderLeadMinutes * 60)
            // Runs whose reminder is still ahead; no job can need more than the budget.
            return job.nextRuns(after: now + lead, count: budget)
                .map(\.instant)
                .filter { $0 - lead < end }
                .map { run in reminder(for: job, run: run, lead: lead, device: device) }
        }
        let sorted = all.sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
        return Array(sorted.prefix(budget))
    }

    /// Which pending identifiers to remove and which reminders to add. Only identifiers
    /// starting `job-` are ours.
    public static func diff(wanted: [JobReminder], pending: Set<String>) -> (remove: [String], add: [JobReminder]) {
        let wantedIDs = Set(wanted.map(\.identifier))
        let remove = pending.filter { $0.hasPrefix(prefix) && !wantedIDs.contains($0) }.sorted()
        return (remove, wanted.filter { !pending.contains($0.identifier) })
    }

    private static func reminder(for job: Job, run: Date, lead: TimeInterval, device: Zone) -> JobReminder {
        let minutes = Int(lead / 60)
        let when = switch minutes {
        case 0: "now"
        case 60: "in 1 hour"
        default: "in \(minutes) min"
        }
        return JobReminder(
            identifier: "\(prefix)\(job.id.uuidString)-\(Int(run.timeIntervalSince1970))", jobID: job.id,
            fireDate: run - lead, run: run, title: "\(job.title) \(when)",
            body: "Expected at \(ZoneClock.timeWithAbbreviation(run, in: device)) · "
                + ScheduleEngine.scheduleLine(job.schedule, in: job.zone))
    }
}

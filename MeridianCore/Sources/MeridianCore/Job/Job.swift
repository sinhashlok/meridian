import Foundation

/// A Jobs entry (spec §4.3, §7): when some recurring work should run, in its own zone.
/// A schedule book, not a monitor: there is no status and no last run (principle 4).
public struct Job: Codable, Hashable, Sendable, Identifiable {
    public enum Category: String, Codable, CaseIterable, Sendable {
        case pipeline, notebook, dashboard, extract, other

        public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    }

    /// A step expected after the parent starts (decision BM). Never "runs after".
    public struct Child: Codable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public var name: String
        /// Elapsed minutes from the parent's start, 0…1439.
        public var offsetMinutes: Int

        public init(id: UUID = UUID(), name: String, offsetMinutes: Int) {
            self.id = id
            self.name = name
            self.offsetMinutes = offsetMinutes
        }
    }

    public let id: UUID
    public var title: String
    public var notes: String
    public var category: Category
    /// Where the real schedule lives (`Airflow DAG netsuite_nightly`); empty = none.
    public var mirrors: String
    public var schedule: Schedule
    /// IANA id the schedule's wall times are read in (default UTC).
    public var zoneID: String
    public var remindsMe: Bool
    /// Minutes before each run; kept when the reminder is turned off.
    public var reminderLeadMinutes: Int
    public var isPaused: Bool
    /// In the phone's zone on the day it was marked.
    public var lastReviewed: CivilDate
    public var children: [Child]

    public init(id: UUID = UUID(), title: String, notes: String = "", category: Category = .pipeline,
                mirrors: String = "", schedule: Schedule, zoneID: String = "UTC", remindsMe: Bool = false,
                reminderLeadMinutes: Int = 10, isPaused: Bool = false, lastReviewed: CivilDate,
                children: [Child] = []) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.mirrors = mirrors
        self.schedule = schedule
        self.zoneID = zoneID
        self.remindsMe = remindsMe
        self.reminderLeadMinutes = reminderLeadMinutes
        self.isPaused = isPaused
        self.lastReviewed = lastReviewed
        self.children = children
    }

    public var zone: Zone { Zone(zoneID) ?? .utc }

    /// Lead-time choices (decision BK): 0 = at the run.
    public static let leadChoices = [0, 5, 10, 15, 30, 60]

    /// The next `count` runs after `now`; empty if paused, invalid or never running.
    public func nextRuns(after now: Date, count: Int) -> [ScheduledRun] {
        guard !isPaused else { return [] }
        return (try? ScheduleEngine.nextRuns(schedule, in: zone, after: now, count: count)) ?? []
    }
}

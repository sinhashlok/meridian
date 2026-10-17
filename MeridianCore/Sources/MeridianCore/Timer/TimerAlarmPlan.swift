import Foundation

/// What the timer Live Activity shows (decision AQ): the soonest timer and "+N more".
/// The app copies it into the ActivityKit content state; the widget only lays it out.
public struct TimerActivityContent: Equatable, Sendable {
    public let title: String
    /// `Ends 21:16 IST`, `Until 02:00 UTC` or `Paused`.
    public let caption: String
    /// Running: the system counts down to this (`Text(timerInterval:)`).
    public let endDate: Date?
    /// Running duration timers: the draining bar runs from here to `endDate`.
    public let progressStart: Date?
    /// Paused: the frozen time left (`06:42`) and bar fraction.
    public let pausedRemaining: String?
    public let pausedFraction: Double?
    /// `+2 more`; `nil` when this is the only timer.
    public let more: String?

    public init(title: String, caption: String, endDate: Date?, progressStart: Date?, pausedRemaining: String?,
                pausedFraction: Double?, more: String?) {
        self.title = title
        self.caption = caption
        self.endDate = endDate
        self.progressStart = progressStart
        self.pausedRemaining = pausedRemaining
        self.pausedFraction = pausedFraction
        self.more = more
    }
}

/// Keeps one alarm per running timer (decision AH) and decides what to change after the
/// app was away (decision AR: AlarmKit's update stream isn't trusted, so the app compares
/// its timers with the alarms the system reports).
public enum TimerAlarmPlan {
    /// A stored timer and the id of the alarm (or notification) last scheduled for it.
    public struct Entry: Sendable {
        public let timer: CountdownTimer
        public let alarmID: UUID?

        public init(timer: CountdownTimer, alarmID: UUID?) {
            self.timer = timer
            self.alarmID = alarmID
        }
    }

    public struct Result: Equatable, Sendable {
        /// Alarm ids to cancel: unknown to us, or belonging to a paused or finished timer.
        public let cancel: [UUID]
        /// Timer ids that are running but have no live alarm: schedule a new one.
        public let schedule: [UUID]
        /// Timer ids whose stored alarm id is stale (paused or finished): set it to nil.
        public let clear: [UUID]

        public var isEmpty: Bool { cancel.isEmpty && schedule.isEmpty && clear.isEmpty }
    }

    /// `scheduled` is what the system reports right now (`AlarmManager.shared.alarms`).
    public static func reconcile(_ entries: [Entry], scheduled: Set<UUID>, now: Date) -> Result {
        let running = entries.filter { $0.timer.status(at: now) == .running }
        let keep = Set(running.compactMap(\.alarmID)).intersection(scheduled)
        return Result(
            cancel: scheduled.subtracting(keep).sorted { $0.uuidString < $1.uuidString },
            schedule: running.filter { $0.alarmID.map { !keep.contains($0) } ?? true }.map(\.timer.id),
            clear: entries.filter { $0.alarmID != nil && $0.timer.status(at: now) != .running }.map(\.timer.id))
    }

    /// The Live Activity for these timers, or `nil` to end it (none running or paused).
    /// Running timers come before paused ones (`TimerText.sorted`).
    public static func activity(_ timers: [CountdownTimer], now: Date, display: Zone) -> TimerActivityContent? {
        let live = TimerText.sorted(timers, now: now).filter { $0.status(at: now) != .finished }
        guard let soonest = live.first else { return nil }
        let card = TimerText.card(soonest, now: now, display: display, displayIsPhone: true)
        let more = live.count > 1 ? "+\(live.count - 1) more" : nil

        if soonest.status(at: now) == .paused {
            return TimerActivityContent(title: card.title, caption: "Paused", endDate: nil, progressStart: nil,
                                        pausedRemaining: card.remaining, pausedFraction: soonest.progress(at: now),
                                        more: more)
        }
        let end = soonest.endDate!
        let caption = card.untilTime.map { "Until " + $0 } ?? card.status ?? ""    // "Ends Fri 00:30 IST"
        let start = soonest.totalSeconds.map { end.addingTimeInterval(-TimeInterval($0)) }
        return TimerActivityContent(title: card.title, caption: caption, endDate: end, progressStart: start,
                                    pausedRemaining: nil, pausedFraction: nil, more: more)
    }
}

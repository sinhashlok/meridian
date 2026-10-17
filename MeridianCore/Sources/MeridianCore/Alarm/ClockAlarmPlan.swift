import Foundation

/// What the app must do so the system's alarms match one ClockAlarm (decisions BD, BF).
/// Compared with what AlarmKit lists right now, never its update stream (M0.5 test 9).
public enum ClockAlarmPlan {
    /// What the app scheduled for one alarm. Store it with the alarm (JSON keeps `Date`
    /// as seconds since 2001, which round-trips exactly; decision BC).
    public struct Scheduled: Codable, Equatable, Sendable {
        /// The alarm settings these ids were scheduled for (`ClockAlarm.fingerprint`).
        public var fingerprint: String
        /// Zoned alarms: AlarmKit id → fixed ring instant.
        public var fixed: [UUID: Date]
        /// Local alarms: the one relative AlarmKit alarm.
        public var relative: UUID?

        public init(fingerprint: String, fixed: [UUID: Date] = [:], relative: UUID? = nil) {
            self.fingerprint = fingerprint
            self.fixed = fixed
            self.relative = relative
        }

        public static let none = Scheduled(fingerprint: "")

        public var allIDs: Set<UUID> { Set(fixed.keys).union(relative.map { [$0] } ?? []) }
    }

    public struct Step: Equatable, Sendable {
        /// Sorted by id.
        public var cancel: [UUID] = []
        /// Fixed instants to schedule, oldest first.
        public var scheduleFixed: [Date] = []
        /// Schedule the Local alarm's relative alarm.
        public var scheduleRelative = false
        /// A one-off that has rung: set the alarm off.
        public var turnOff = false
        /// `scheduled` after the cancels; add the new ids to it.
        public var kept: Scheduled

        public init(cancel: [UUID] = [], scheduleFixed: [Date] = [], scheduleRelative: Bool = false,
                    turnOff: Bool = false, kept: Scheduled) {
            self.cancel = cancel
            self.scheduleFixed = scheduleFixed
            self.scheduleRelative = scheduleRelative
            self.turnOff = turnOff
            self.kept = kept
        }
    }

    public static func step(for alarm: ClockAlarm, scheduled: Scheduled, live: Set<UUID>, now: Date,
                            device: Zone) -> Step {
        let fresh = Scheduled(fingerprint: alarm.fingerprint)
        // A one-off that has rung: wait while it's still alerting or snoozed, then turn off.
        if alarm.isOn, alarm.isSpent(at: now) {
            guard scheduled.allIDs.isDisjoint(with: live) else { return Step(kept: scheduled) }
            return Step(cancel: sorted(scheduled.allIDs), turnOff: true, kept: fresh)
        }

        var kept = scheduled
        var cancel: Set<UUID> = []
        // Changed settings or switched off: replace everything.
        if kept.fingerprint != alarm.fingerprint || !alarm.isOn {
            cancel = kept.allIDs
            kept = fresh
        }
        guard alarm.isOn else { return Step(cancel: sorted(cancel), kept: kept) }

        if alarm.isLocal {
            // One relative alarm on the phone's wall clock (decision BD).
            cancel.formUnion(kept.fixed.keys)
            kept.fixed = [:]
            if let relative = kept.relative, live.contains(relative) {
                return Step(cancel: sorted(cancel), kept: kept)
            }
            if let relative = kept.relative { cancel.insert(relative) }
            kept.relative = nil
            return Step(cancel: sorted(cancel), scheduleRelative: true, kept: kept)
        }

        // Zoned: fixed rings for the window (decision BD).
        if let relative = kept.relative { cancel.insert(relative) }
        kept.relative = nil
        // A past ring the system still lists is alerting or snoozed: leave it alone.
        let ringing = kept.fixed.filter { $0.value <= now && live.contains($0.key) }
        let rest = kept.fixed.filter { ringing[$0.key] == nil }
        let plan = AlarmDiff.plan(wanted: alarm.rings(after: now, within: ClockAlarm.window, device: device),
                                  stored: rest, live: live)
        for id in plan.cancel {
            cancel.insert(id)
            kept.fixed[id] = nil
        }
        return Step(cancel: sorted(cancel), scheduleFixed: plan.schedule, kept: kept)
    }

    private static func sorted(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }
}

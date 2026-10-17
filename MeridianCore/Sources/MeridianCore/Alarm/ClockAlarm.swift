import Foundation

/// A wake-up alarm (spec §4.2, §7 `Alarm`; decisions BD, BE). Named `ClockAlarm`
/// because AlarmKit already has an `Alarm` type.
public struct ClockAlarm: Codable, Hashable, Sendable, Identifiable {
    /// "When clocks change" (spec §4.2).
    public enum Policy: Codable, Hashable, Sendable {
        /// Always this wall time in the alarm's zone (default).
        case keepZone
        /// Always this UTC time, worked out once at Save (decision BE).
        case keepUTC(ClockTime)
    }

    public let id: UUID
    /// The wall time in the alarm's zone, as picked on the wheel.
    public var time: ClockTime
    /// IANA id; `nil` = Local, the phone's wall clock wherever it is.
    public var zoneID: String?
    public var policy: Policy
    /// ISO weekdays (Monday = 1) in the alarm's zone; empty = rings once.
    public var repeatDays: Set<Int>
    public var label: String
    /// `nil` = snooze off.
    public var snoozeMinutes: Int?
    public var isOn: Bool
    /// One-off alarms: the instant it was armed for (decision BF). Set by `armed`.
    public private(set) var onceAt: Date?

    /// How far ahead zoned alarms are scheduled as fixed instants (decision BD): elapsed
    /// time, not "14 days" on any calendar.
    public static let window: TimeInterval = 14 * 24 * 3600

    public init(id: UUID = UUID(), time: ClockTime, zoneID: String?, policy: Policy, repeatDays: Set<Int>,
                label: String, snoozeMinutes: Int?, isOn: Bool) {
        self.id = id
        self.time = time
        self.zoneID = zoneID
        self.policy = policy
        self.repeatDays = repeatDays
        self.label = label
        self.snoozeMinutes = snoozeMinutes
        self.isOn = isOn
    }

    public var isLocal: Bool { zoneID == nil }

    /// A copy ready to schedule: a one-off that is on gets its ring instant fixed, so it
    /// never slides to the next day (decision BF). Call on every save and switch-on.
    public func armed(now: Date, device: Zone) -> ClockAlarm {
        var copy = self
        copy.onceAt = nil
        if isOn, repeatDays.isEmpty { copy.onceAt = copy.nextRing(after: now, device: device) }
        return copy
    }

    /// A one-off whose ring has passed.
    public func isSpent(at now: Date) -> Bool {
        repeatDays.isEmpty && (onceAt.map { $0 <= now } ?? false)
    }

    /// Changes whenever what AlarmKit was given would change (time, zone, days, title,
    /// snooze, armed instant), so the old system alarms are replaced.
    public var fingerprint: String {
        let policyText = switch policy {
        case .keepZone: "zone"
        case .keepUTC(let utc): "utc \(utc.text)"
        }
        return [time.text, zoneID ?? "local", policyText, repeatDays.sorted().map(String.init).joined(separator: ","),
                label, snoozeMinutes.map(String.init) ?? "-",
                onceAt.map { "\($0.timeIntervalSinceReferenceDate)" } ?? "-"].joined(separator: "|")
    }

    /// The UTC time of day that `time` in `zone` is on `instant`'s date there (BE):
    /// 09:00 New York on 16 Oct → 13:00, on 2 Nov → 14:00.
    public static func utcTime(of time: ClockTime, in zone: Zone, at instant: Date) -> ClockTime {
        let date = ZoneClock.local(instant, in: zone).date
        let ring = ZoneClock.resolve(LocalDateTime(date: date, hour: time.hour, minute: time.minute), in: zone,
                                     occurrence: .first)
        let utc = ZoneClock.local(ring.instant, in: .utc)
        return ClockTime(utc.hour, utc.minute)
    }

    /// The zone the alarm's wall time and repeat days are read in.
    public func zone(device: Zone) -> Zone {
        zoneID.flatMap(Zone.init) ?? device
    }

    /// Ring instants strictly after `now` and before `now + within`, oldest first.
    /// A one-off alarm (no repeat days) gives at most one. Wall times go through
    /// `RunGenerator`, so a skipped time rings at the next valid time and a repeated one
    /// rings once, at its first occurrence (spec §5.2).
    public func rings(after now: Date, within: TimeInterval, device: Zone) -> [Date] {
        let end = now.addingTimeInterval(within)
        if repeatDays.isEmpty, let onceAt { return onceAt > now && onceAt < end ? [onceAt] : [] }
        let zone = zone(device: device)
        let repeatDays = repeatDays
        // One alarm time per day, so this many runs always covers the window.
        let count = repeatDays.isEmpty ? 1 : Int(within / 86_400) + 2

        let runs: [ScheduledRun]
        switch policy {
        case .keepZone:
            runs = RunGenerator.nextRuns(after: now, in: zone, count: count, times: [time.timeOfDay]) { date in
                repeatDays.isEmpty || repeatDays.contains(date.isoWeekday)
            }
        case .keepUTC(let utcTime):
            // The UTC day steps along; the repeat day is the alarm zone's date at that instant.
            runs = RunGenerator.nextRuns(after: now, in: .utc, count: count, times: [utcTime.timeOfDay]) { date in
                guard !repeatDays.isEmpty else { return true }
                let instant = ZoneClock.startOfDay(date, in: .utc)
                    .addingTimeInterval(TimeInterval(utcTime.minutesAfterMidnight * 60))
                return repeatDays.contains(ZoneClock.local(instant, in: zone).date.isoWeekday)
            }
        }
        return runs.map(\.instant).filter { $0 < end }
    }

    /// The next ring after `now`. Every alarm rings within a week (a day for one-offs);
    /// the search window is that elapsed time plus two hours of slack for clock changes.
    public func nextRing(after now: Date, device: Zone) -> Date? {
        let days = repeatDays.isEmpty ? 1 : 8
        return rings(after: now, within: TimeInterval(days * 86_400 + 7_200), device: device).first
    }
}

extension ClockTime {
    var timeOfDay: TimeOfDay { TimeOfDay(hour: hour, minute: minute, second: 0) }
}

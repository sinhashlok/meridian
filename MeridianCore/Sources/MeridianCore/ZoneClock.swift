import Foundation

/// A validated IANA zone (`"America/New_York"`). Store `id`; never an offset or abbreviation.
public struct Zone: Hashable, Sendable {
    public let id: String
    let timeZone: TimeZone

    public init?(_ id: String) {
        guard !id.isEmpty, let timeZone = TimeZone(identifier: id) else { return nil }
        self.id = id
        self.timeZone = timeZone
    }

    public static let utc = Zone("UTC")!

    /// `New York` from `America/New_York`; `UTC` for UTC. For schedule lines and notes.
    public var cityName: String {
        isUTC ? "UTC" : (id.split(separator: "/").last.map(String.init) ?? id).replacingOccurrences(of: "_", with: " ")
    }

    /// Ids that mean plain UTC and are written `UTC` (CLAUDE.md time rules).
    var isUTC: Bool {
        ["UTC", "Etc/UTC", "UCT", "Etc/UCT", "Universal", "Etc/Universal", "Zulu", "Etc/Zulu", "GMT", "Etc/GMT"]
            .contains(id)
    }

    /// Gregorian calendar in this zone. Fine for zone conversions (all after 1582).
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

/// Which instant to pick when a wall time happens twice (clocks going back).
public enum Occurrence: Sendable { case first, second }

/// A wall time resolved to an instant under the gap/overlap rule (spec §5.2).
public struct Resolution: Equatable, Sendable {
    public enum Kind: Sendable {
        /// The wall time exists once.
        case exact
        /// The wall time doesn't exist (clocks went forward); moved to the next valid time.
        case skipped
        /// The wall time happens twice (clocks went back); the requested occurrence was used.
        case repeated
    }

    public let instant: Date
    public let kind: Kind
}

/// A zone's offset and naming at one instant.
public struct ZoneState: Equatable, Sendable {
    public let offsetSeconds: Int
    /// From the curated table (decision B); `nil` for zones without a widely used one.
    public let abbreviation: String?
    /// `BST (UTC+1)`, `UTC+5:45`, or `UTC`.
    public let label: String
}

/// A clock change: the zone's state just before and from `instant`.
public struct Transition: Equatable, Sendable {
    public let instant: Date
    public let before: ZoneState
    public let after: ZoneState
}

/// Zone conversions for every screen. Views ask this instead of using `TimeZone` or
/// `Calendar` (CLAUDE.md rule 2).
public enum ZoneClock {
    /// `UTC+5:30`, `UTC−7` (U+2212 minus), `UTC+0`.
    public static func offsetLabel(seconds: Int) -> String {
        let sign = seconds < 0 ? "−" : "+"
        let magnitude = abs(seconds)
        let hours = magnitude / 3600, minutes = magnitude % 3600 / 60
        return "UTC\(sign)\(hours)" + (minutes == 0 ? "" : ":" + twoDigits(minutes))
    }

    public static func state(_ zone: Zone, at instant: Date) -> ZoneState {
        let offset = zone.timeZone.secondsFromGMT(for: instant)
        if zone.isUTC {
            return ZoneState(offsetSeconds: offset, abbreviation: "UTC", label: "UTC")
        }
        let abbreviation = ZoneAbbreviations.abbreviation(
            for: zone.id, isDaylightSaving: zone.timeZone.isDaylightSavingTime(for: instant))
        let offsetText = offsetLabel(seconds: offset)
        return ZoneState(offsetSeconds: offset, abbreviation: abbreviation,
                         label: abbreviation.map { "\($0) (\(offsetText))" } ?? offsetText)
    }

    /// `BST (UTC+1)`; `UTC+5:45` without a curated abbreviation; `UTC` for UTC.
    public static func label(_ zone: Zone, at instant: Date) -> String {
        state(zone, at: instant).label
    }

    /// The wall-clock date and time of `instant` in `zone` (seconds dropped).
    public static func local(_ instant: Date, in zone: Zone) -> LocalDateTime {
        let parts = zone.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        return LocalDateTime(date: CivilDate(parts.year!, parts.month!, parts.day!),
                             hour: parts.hour!, minute: parts.minute!)
    }

    /// `17:00`: 24-hour wall time of `instant` in `zone`.
    public static func wallTime(_ instant: Date, in zone: Zone) -> String {
        let time = local(instant, in: zone)
        return twoDigits(time.hour) + ":" + twoDigits(time.minute)
    }

    /// `17:00 BST (UTC+1)`: what copy and share use. Always carries the offset.
    public static func copyText(_ instant: Date, in zone: Zone) -> String {
        wallTime(instant, in: zone) + " " + label(zone, at: instant)
    }

    /// Clock changes in `zone` with `start <= instant < end`, oldest first.
    public static func transitions(in zone: Zone, from start: Date, to end: Date) -> [Transition] {
        var result: [Transition] = []
        var cursor = start.addingTimeInterval(-1)
        while let instant = zone.timeZone.nextDaylightSavingTimeTransition(after: cursor), instant < end {
            result.append(Transition(instant: instant,
                                     before: state(zone, at: instant.addingTimeInterval(-1)),
                                     after: state(zone, at: instant)))
            cursor = instant
        }
        return result
    }

    /// Length of `date` in `zone`, in seconds: 82_800, 86_400 or 90_000 around DST.
    public static func dayLength(of date: CivilDate, in zone: Zone) -> Int {
        let calendar = zone.calendar
        guard let interval = calendar.dateInterval(of: .day, for: noon(of: date, calendar: calendar)) else {
            preconditionFailure("no day interval for \(date) in \(zone.id)")
        }
        return Int(interval.duration)
    }

    /// The first instant of `date` in `zone` (local midnight, or the first valid time
    /// if midnight was skipped).
    public static func startOfDay(_ date: CivilDate, in zone: Zone) -> Date {
        let calendar = zone.calendar
        guard let start = calendar.dateInterval(of: .day, for: noon(of: date, calendar: calendar))?.start else {
            preconditionFailure("no day start for \(date) in \(zone.id)")
        }
        return start
    }

    /// The gap/overlap rule (spec §5.2): a skipped time moves to the next valid time
    /// (02:30 → 03:00 EDT); a repeated time uses `occurrence`.
    ///
    /// Uses `Calendar.nextDate` with `.nextTime`. Never `Calendar.date(from:)`, which
    /// moves skipped times by the gap length (02:30 → 03:30), like Python `zoneinfo`.
    public static func resolve(_ time: LocalDateTime, in zone: Zone, occurrence: Occurrence) -> Resolution {
        let calendar = zone.calendar
        guard let dayStart = calendar.dateInterval(of: .day, for: noon(of: time.date, calendar: calendar))?.start else {
            preconditionFailure("no day start for \(time.date) in \(zone.id)")
        }
        let searchFrom = dayStart.addingTimeInterval(-1)
        let wanted = DateComponents(hour: time.hour, minute: time.minute)

        func find(_ policy: Calendar.RepeatedTimePolicy) -> Date {
            guard let date = calendar.nextDate(after: searchFrom, matching: wanted, matchingPolicy: .nextTime,
                                               repeatedTimePolicy: policy, direction: .forward)
            else { preconditionFailure("no \(time.hour):\(time.minute) after \(searchFrom) in \(zone.id)") }
            return date
        }

        let first = find(.first), second = find(.last)
        if first != second {
            return Resolution(instant: occurrence == .first ? first : second, kind: .repeated)
        }
        let found = calendar.dateComponents([.hour, .minute], from: first)
        let isExact = found.hour == time.hour && found.minute == time.minute
        return Resolution(instant: first, kind: isExact ? .exact : .skipped)
    }

    /// The next time the wall clock in `zone` reads `hour:minute` after `instant`
    /// (first occurrence if repeated, next valid time if skipped). For Until timers.
    public static func nextOccurrence(hour: Int, minute: Int, in zone: Zone, after instant: Date) -> Date {
        guard let date = zone.calendar.nextDate(after: instant, matching: DateComponents(hour: hour, minute: minute),
                                                matchingPolicy: .nextTime, repeatedTimePolicy: .first,
                                                direction: .forward)
        else { preconditionFailure("no \(hour):\(minute) after \(instant) in \(zone.id)") }
        return date
    }

    // MARK: Private

    /// Local noon on `date`: inside the day and never in a DST gap.
    private static func noon(of date: CivilDate, calendar: Calendar) -> Date {
        guard let noon = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: 12))
        else { preconditionFailure("no noon on \(date)") }
        return noon
    }
}

extension Zone {
    /// The phone's current zone (UTC if Foundation reports an unknown id).
    public static var device: Zone { Zone(TimeZone.current.identifier) ?? .utc }

    /// For APIs that need a Foundation `TimeZone`, e.g. a `DatePicker` environment.
    /// Views use this instead of creating a `TimeZone` themselves.
    public var foundationTimeZone: TimeZone { timeZone }
}

import Foundation

/// A wall-clock time of day in a schedule's zone (`02:00`).
public struct ClockTime: Hashable, Comparable, Codable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(_ hour: Int, _ minute: Int) {
        precondition((0...23).contains(hour) && (0...59).contains(minute), "invalid time \(hour):\(minute)")
        self.hour = hour
        self.minute = minute
    }

    public static func < (a: ClockTime, b: ClockTime) -> Bool { (a.hour, a.minute) < (b.hour, b.minute) }

    /// `02:00`.
    public var text: String { twoDigits(hour) + ":" + twoDigits(minute) }
}

public enum MonthDay: Hashable, Sendable {
    /// 1–31; months without that day are skipped.
    case day(Int)
    case last
}

/// A Job's schedule (spec §4.3 SchedulePicker, §7 data model). Always paired with an
/// IANA zone; wall times are resolved there with the gap/overlap rule.
public enum Schedule: Hashable, Sendable {
    /// On the wall clock, like cron `*/N` (decision F). N must divide 60.
    case everyMinutes(Int)
    /// At minute 0 of every Nth hour from midnight. N must divide 24.
    case everyHours(Int)
    case daily(times: [ClockTime])
    /// `days` are ISO weekdays: Monday = 1 … Sunday = 7.
    case weekly(days: Set<Int>, time: ClockTime)
    case monthly(day: MonthDay, time: ClockTime)
    case cron(dialect: CronDialect, expression: String)
}

public enum ScheduleError: Error, Equatable, Sendable {
    case invalidInterval(Int, allowed: [Int])
    case noTimes
    case noDays
    case invalidDay(Int)
    case cron(CronError)
}

/// A one-line, neutral note shown with a schedule (never a status).
public struct ScheduleWarning: Equatable, Sendable {
    public let message: String
}

public enum ScheduleEngine {
    public static let minuteIntervals = [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30]
    public static let hourIntervals = [1, 2, 3, 4, 6, 8, 12]

    /// The next `count` runs after `instant` in `zone`, oldest first. Empty if it never runs.
    public static func nextRuns(_ schedule: Schedule, in zone: Zone, after instant: Date,
                                count: Int) throws(ScheduleError) -> [ScheduledRun] {
        let everyDay: (CivilDate) -> Bool = { _ in true }

        switch schedule {
        case .everyMinutes(let n):
            guard minuteIntervals.contains(n) else { throw .invalidInterval(n, allowed: minuteIntervals) }
            let times = (0..<24).flatMap { hour in stride(from: 0, to: 60, by: n).map { TimeOfDay(hour: hour, minute: $0, second: 0) } }
            return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: times, matchesDay: everyDay)

        case .everyHours(let n):
            guard hourIntervals.contains(n) else { throw .invalidInterval(n, allowed: hourIntervals) }
            let times = stride(from: 0, to: 24, by: n).map { TimeOfDay(hour: $0, minute: 0, second: 0) }
            return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: times, matchesDay: everyDay)

        case .daily(let clockTimes):
            guard !clockTimes.isEmpty else { throw .noTimes }
            return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: timesOfDay(clockTimes),
                                         matchesDay: everyDay)

        case .weekly(let days, let time):
            guard !days.isEmpty, days.allSatisfy({ (1...7).contains($0) }) else { throw .noDays }
            return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: timesOfDay([time])) {
                days.contains($0.isoWeekday)
            }

        case .monthly(let monthDay, let time):
            if case .day(let day) = monthDay, !(1...31).contains(day) { throw .invalidDay(day) }
            return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: timesOfDay([time])) { date in
                switch monthDay {
                case .day(let day): date.day == day
                case .last: date.day == PeriodEngine.daysInMonth(date.year, date.month)
                }
            }

        case .cron(let dialect, let text):
            do {
                return try CronExpression.parse(text, dialect: dialect).nextRuns(after: instant, in: zone, count: count)
            } catch {
                throw .cron(error)
            }
        }
    }

    /// The Jobs list schedule line, always in the job's zone: `Daily · 02:00 UTC`.
    public static func scheduleLine(_ schedule: Schedule, in zone: Zone) -> String {
        let place = zone.cityName
        switch schedule {
        case .everyMinutes(let n):
            return "Every \(n) min"
        case .everyHours(let n):
            return "Every \(n) hour\(n == 1 ? "" : "s") · \(place)"
        case .daily(let times):
            return "Daily · " + Array(Set(times)).sorted().map(\.text).joined(separator: ", ") + " \(place)"
        case .weekly(let days, let time):
            return "Weekly · \(weekdayList(days)) · \(time.text) \(place)"
        case .monthly(let monthDay, let time):
            let day = switch monthDay {
            case .day(let day): "day \(day)"
            case .last: "last day"
            }
            return "Monthly · \(day) · \(time.text) \(place)"
        case .cron(_, let text):
            return "Cron · \(text.trimmingCharacters(in: .whitespaces)) · \(place)"
        }
    }

    /// Notes for the schedule and for the runs shown. DST notes name the reading used
    /// and end "Your scheduler may differ." (spec §5.2).
    public static func warnings(_ schedule: Schedule, in zone: Zone, runs: [ScheduledRun]) -> [ScheduleWarning] {
        var warnings: [ScheduleWarning] = []
        if case .monthly(.day(let day), _) = schedule {
            switch day {
            case 31: warnings.append(ScheduleWarning(message: "Skips months without day 31"))
            case 30: warnings.append(ScheduleWarning(message: "Skips February"))
            case 29: warnings.append(ScheduleWarning(message: "Skips February except in leap years"))
            default: break
            }
        }
        for run in runs {
            let asked = ClockTime(run.wallTime.hour, run.wallTime.minute).text
            let when = run.wallTime.date.shortText
            let actual = ZoneClock.copyText(run.instant, in: zone)
            switch run.kind {
            case .exact:
                continue
            case .skipped:
                warnings.append(ScheduleWarning(message:
                    "\(when): \(asked) doesn't exist in \(zone.cityName), so this run is at \(actual). Your scheduler may differ."))
            case .repeated:
                warnings.append(ScheduleWarning(message:
                    "\(when): \(asked) happens twice in \(zone.cityName); this uses the first, \(actual). Your scheduler may differ."))
            }
        }
        return warnings
    }

    // MARK: Private

    private static let weekdayShortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private static func timesOfDay(_ times: [ClockTime]) -> [TimeOfDay] {
        Array(Set(times)).sorted().map { TimeOfDay(hour: $0.hour, minute: $0.minute, second: 0) }
    }

    /// `Mon, Wed` or `Mon–Fri` for three or more consecutive days.
    private static func weekdayList(_ days: Set<Int>) -> String {
        let sorted = days.sorted()
        if sorted.count >= 3, zip(sorted, sorted.dropFirst()).allSatisfy({ $1 == $0 + 1 }) {
            return weekdayShortNames[sorted.first! - 1] + "–" + weekdayShortNames[sorted.last! - 1]
        }
        return sorted.map { weekdayShortNames[$0 - 1] }.joined(separator: ", ")
    }
}

extension ClockTime {
    /// 0…1439, for storage (SwiftData keeps an Int, not a struct).
    public init(minutesAfterMidnight minutes: Int) {
        self.init(minutes / 60, minutes % 60)
    }

    public var minutesAfterMidnight: Int { hour * 60 + minute }

    /// This time on 2000-01-01 in UTC, for a `DatePicker` shown in UTC
    /// (`Zone.utc.foundationTimeZone`), so the device's zone can never shift it.
    public var referenceDate: Date {
        Date(timeIntervalSince1970: 946_684_800 + TimeInterval(minutesAfterMidnight * 60))   // 2000-01-01T00:00Z
    }

    /// The time of day of `date` read in UTC (inverse of `referenceDate`).
    public init(referenceDate date: Date) {
        let local = ZoneClock.local(date, in: .utc)
        self.init(local.hour, local.minute)
    }
}

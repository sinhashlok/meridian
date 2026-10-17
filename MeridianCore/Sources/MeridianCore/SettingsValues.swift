import Foundation

/// Settings › Week start (decision BY). Orders weekday chips and day lists only:
/// ISO weeks always start Monday and fiscal profiles set their own.
public enum WeekStart: String, CaseIterable, Codable, Sendable {
    case followLocale, monday, sunday, saturday

    /// `Follow locale`, `Monday`, …
    public var title: String {
        switch self {
        case .followLocale: "Follow locale"
        case .monday: "Monday"
        case .sunday: "Sunday"
        case .saturday: "Saturday"
        }
    }

    /// The first day as an ISO weekday (Monday = 1 … Sunday = 7).
    public func firstDay(for locale: Locale) -> Int {
        switch self {
        case .monday: 1
        case .sunday: 7
        case .saturday: 6
        case .followLocale: Self.isoWeekdays.firstIndex(of: locale.firstDayOfWeek).map { $0 + 1 } ?? 1
        }
    }

    private static let isoWeekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday,
                                                        .saturday, .sunday]
}

/// ISO weekdays (Monday = 1 … Sunday = 7) in display order and as short text.
public enum Weekdays {
    /// All seven, starting with `first`.
    public static func ordered(from first: Int) -> [Int] {
        (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    /// `Mon–Fri`, `Mon–Thu, Sat`, `Sun–Thu` (Sunday-first week), `Every day`, `None`.
    /// Three or more days in a row (in `first`'s order) become a range.
    public static func summary(_ days: Set<Int>, from first: Int = 1) -> String {
        if days.isEmpty { return "None" }
        if days.count == 7 { return "Every day" }
        return text(days, from: first, names: shortNames, to: "–")
    }

    static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let fullNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    /// Runs of consecutive chosen days, walking the week in display order; three or more
    /// in a row become `first<to>last`.
    private static func text(_ days: Set<Int>, from first: Int, names: [String], to: String) -> String {
        var runs: [[Int]] = []
        var previousChosen = false
        for day in ordered(from: first) {
            let chosen = days.contains(day)
            if chosen { previousChosen ? runs[runs.count - 1].append(day) : runs.append([day]) }
            previousChosen = chosen
        }
        return runs.flatMap { run in
            run.count >= 3 ? [names[run.first! - 1] + to + names[run.last! - 1]] : run.map { names[$0 - 1] }
        }
        .joined(separator: ", ")
    }
}

extension ClockTime {
    /// `09:00–18:00` (Settings › Default working hours).
    public static func rangeText(_ start: ClockTime, _ end: ClockTime) -> String {
        start.text + "–" + end.text
    }
}

extension ZoneClock {
    /// The IANA time zone database version iOS ships, e.g. `2025b` (Settings › About).
    public static var dataVersion: String { TimeZone.timeZoneDataVersion }
}

extension Weekdays {
    /// For VoiceOver: `Monday to Friday`, `Monday to Thursday, Saturday`.
    public static func spokenSummary(_ days: Set<Int>, from first: Int = 1) -> String {
        if days.isEmpty { return "no work days" }
        if days.count == 7 { return "every day" }
        return text(days, from: first, names: fullNames, to: " to ")
    }
}

extension PlannerZone {
    /// What VoiceOver reads for a Planner row (decision CC): `Mumbai, home, 21:30 IST,
    /// stretch hours. Work hours 09:00 to 18:00, Monday to Friday.`
    public func spokenRow(at instant: Date, isHome: Bool) -> String {
        let kind = switch self.kind(at: instant) {
        case .work: "work hours"
        case .stretch: "stretch hours"
        case .sleep: "asleep"
        }
        let weekend = isWorkDay(ZoneClock.local(instant, in: zone).date) ? "" : "weekend, "
        return "\(name), " + (isHome ? "home, " : "")
            + "\(ZoneClock.wallTime(instant, in: zone)) \(ZoneClock.shortName(zone, at: instant)), \(weekend)\(kind). "
            + "Work hours \(workStart.text) to \(workEnd.text), \(Weekdays.spokenSummary(workDays))."
    }
}

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
        // Runs of consecutive chosen days, walking the week in display order.
        var runs: [[Int]] = []
        var previousChosen = false
        for day in ordered(from: first) {
            let chosen = days.contains(day)
            if chosen { previousChosen ? runs[runs.count - 1].append(day) : runs.append([day]) }
            previousChosen = chosen
        }
        return runs.flatMap { run in
            run.count >= 3 ? [shortNames[run.first! - 1] + "–" + shortNames[run.last! - 1]]
                           : run.map { shortNames[$0 - 1] }
        }
        .joined(separator: ", ")
    }

    static let shortNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
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

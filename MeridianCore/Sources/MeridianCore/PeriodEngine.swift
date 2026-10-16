import Foundation

/// An ISO 8601 week: weeks start Monday; week 1 is the week with the year's first Thursday.
public struct ISOWeek: Hashable, Sendable {
    /// The ISO week-year, which can differ from the calendar year (2025-12-29 is 2026-W01).
    public let year: Int
    public let week: Int

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    /// Always `YYYY-Www` (`2026-W01`).
    public var text: String {
        "\(year)-W" + (week < 10 ? "0\(week)" : "\(week)")
    }
}

/// An ISO week and its Monday and Sunday.
public struct WeekRange: Hashable, Sendable {
    public let week: ISOWeek
    public let start: CivilDate
    public let end: CivilDate
}

/// The Dates tool's date rows (spec §4.6).
public struct DateInfo: Hashable, Sendable {
    public let isoWeek: ISOWeek
    public let weekRange: WeekRange
    /// Monday = 1 … Sunday = 7.
    public let isoWeekday: Int
    public let dayOfYear: Int
    public let daysInYear: Int
    public let quarter: Int
    public let dayOfQuarter: Int
    public let daysInQuarter: Int
    public let daysLeftInYear: Int
}

public enum PeriodError: Error, Equatable, Sendable {
    case invalidFormat
    /// The week number is outside 1...`weeks` for that ISO year.
    case weekOutOfRange(year: Int, weeks: Int)
}

/// Date-only maths for the Dates tool. A 23- or 25-hour day is one day (spec §5.3).
public enum PeriodEngine {
    public static func info(for date: CivilDate) -> DateInfo {
        let week = isoWeek(of: date)
        let yearStart = CivilDate(date.year, 1, 1)
        let dayOfYear = date.days(since: yearStart) + 1
        let daysInYear = GregorianDays.isLeapYear(Int64(date.year)) ? 366 : 365

        let quarter = (date.month - 1) / 3 + 1
        let firstMonth = (quarter - 1) * 3 + 1
        let quarterStart = CivilDate(date.year, firstMonth, 1)
        let daysInQuarter = (firstMonth..<firstMonth + 3).reduce(0) { $0 + daysInMonth(date.year, $1) }

        return DateInfo(isoWeek: week, weekRange: range(of: week), isoWeekday: date.isoWeekday,
                        dayOfYear: dayOfYear, daysInYear: daysInYear,
                        quarter: quarter, dayOfQuarter: date.days(since: quarterStart) + 1,
                        daysInQuarter: daysInQuarter, daysLeftInYear: daysInYear - dayOfYear)
    }

    public static func isoWeek(of date: CivilDate) -> ISOWeek {
        // The week belongs to the year its Thursday is in.
        let thursday = date.adding(days: 4 - date.isoWeekday)
        let week = thursday.days(since: CivilDate(thursday.year, 1, 1)) / 7 + 1
        return ISOWeek(year: thursday.year, week: week)
    }

    /// 52 or 53. 28 December is always in the year's last ISO week.
    public static func weeksInISOYear(_ year: Int) -> Int {
        isoWeek(of: CivilDate(year, 12, 28)).week
    }

    /// Parses `2026-W44` (also `2026W44`, lowercase `w`).
    public static func parseISOWeek(_ text: String) throws(PeriodError) -> WeekRange {
        guard let match = text.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d{4})-?[Ww](\d{2})/),
              let year = Int(match.output.1), let week = Int(match.output.2), (1...9998).contains(year)
        else { throw .invalidFormat }
        let weeks = weeksInISOYear(year)
        guard (1...weeks).contains(week) else { throw .weekOutOfRange(year: year, weeks: weeks) }
        return range(of: ISOWeek(year: year, week: week))
    }

    // MARK: Internal

    static func range(of week: ISOWeek) -> WeekRange {
        let january4 = CivilDate(week.year, 1, 4)                         // always in week 1
        let week1Monday = january4.adding(days: 1 - january4.isoWeekday)
        let start = week1Monday.adding(days: (week.week - 1) * 7)
        return WeekRange(week: week, start: start, end: start.adding(days: 6))
    }

    static func daysInMonth(_ year: Int, _ month: Int) -> Int {
        Int(GregorianDays.daysInMonth(year: Int64(year), month: Int64(month)))
    }
}

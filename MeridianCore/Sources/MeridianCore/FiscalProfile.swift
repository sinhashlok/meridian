import Foundation

/// A company's fiscal calendar (spec §4.6). Up to 3 are saved; one is active.
/// `Codable` so the app can store it as JSON (decision Y), like a dataclass with to/from JSON.
public struct FiscalProfile: Hashable, Sendable, Codable {
    /// Which week is week 1, for calendar-month profiles (decision A, docs/decisions.md).
    public enum Week1Rule: Hashable, Sendable, Codable {
        /// Week 1 is the whole calendar week containing the year start. Days before the
        /// start in that week are week 1 of the new year, like ISO week-years.
        case containsYearStart
        /// Week 1 starts on the year start and ends with that calendar week.
        case startsOnYearStart
    }

    /// Weeks per period in each quarter.
    public enum Pattern: Hashable, Sendable, Codable {
        case p445, p454, p544

        var weeksPerQuarter: [Int] {
            switch self {
            case .p445: [4, 4, 5]
            case .p454: [4, 5, 4]
            case .p544: [5, 4, 4]
            }
        }
    }

    /// Where a week-based year ends: on the week's last weekday...
    public enum YearEndRule: Hashable, Sendable, Codable {
        /// ...that is the last one in the end month.
        case lastInMonth
        /// ...nearest the end month's last day (up to 3 days either side).
        case nearestMonthEnd
    }

    public enum Basis: Hashable, Sendable, Codable {
        /// Periods are calendar months; the year starts on the 1st of `startMonth`.
        case calendarMonths(week1: Week1Rule)
        /// Periods are whole weeks in a 4-4-5-style pattern; a 53rd week joins the last period.
        case weekBased(pattern: Pattern, yearEnd: YearEndRule)
    }

    /// `FY27` (named by the year it ends in) or `FY2026-27`.
    public enum Naming: Hashable, Sendable, Codable { case short, long }

    public let name: String
    /// 1 = January … 12 = December.
    public let startMonth: Int
    /// ISO weekday weeks start on: 1 = Monday … 7 = Sunday.
    public let weekStart: Int
    public let basis: Basis
    public let naming: Naming

    public init(name: String, startMonth: Int, weekStart: Int, basis: Basis, naming: Naming) {
        precondition((1...12).contains(startMonth), "startMonth must be 1...12")
        precondition((1...7).contains(weekStart), "weekStart must be an ISO weekday 1...7")
        self.name = name
        self.startMonth = startMonth
        self.weekStart = weekStart
        self.basis = basis
        self.naming = naming
    }

    /// The fiscal year whose nominal start month falls in `startYear`
    /// (`startingIn: 2026` is FY27 for an April start, FY2026-27 for retail).
    public func fiscalYear(startingIn startYear: Int) -> FiscalYear {
        let start = firstDay(startYear), end = lastDay(startYear)
        switch basis {
        case .calendarMonths:
            let periods = (0..<12).map { index -> FiscalPeriod in
                let monthIndex = startMonth - 1 + index
                let year = startYear + monthIndex / 12, month = monthIndex % 12 + 1
                return FiscalPeriod(number: index + 1, name: "P\(index + 1) \(Self.monthNames[month - 1])",
                                    start: CivilDate(year, month, 1),
                                    end: CivilDate(year, month, PeriodEngine.daysInMonth(year, month)), weeks: nil)
            }
            return FiscalYear(startYear: startYear, name: yearName(startYear), start: start, end: end,
                              weekCount: nil, periods: periods)

        case .weekBased(let pattern, _):
            let weekCount = (end.days(since: start) + 1) / 7
            var weeks = Array(repeating: pattern.weeksPerQuarter, count: 4).flatMap { $0 }
            weeks[11] += weekCount - 52                                   // 53rd week → last period
            var periodStart = start
            let periods = weeks.enumerated().map { index, count -> FiscalPeriod in
                let period = FiscalPeriod(number: index + 1, name: "P\(index + 1)", start: periodStart,
                                          end: periodStart.adding(days: count * 7 - 1), weeks: count)
                periodStart = periodStart.adding(days: count * 7)
                return period
            }
            return FiscalYear(startYear: startYear, name: yearName(startYear), start: start, end: end,
                              weekCount: weekCount, periods: periods)
        }
    }

    /// Fiscal year, quarter, period, day and week for `date`.
    public func info(for date: CivilDate) -> FiscalInfo {
        let year = fiscalYear(startingIn: startYear(containing: date))
        guard let period = year.periods.first(where: { $0.start <= date && date <= $0.end }) else {
            preconditionFailure("\(date) is in no period of \(year.name)")
        }
        let quarter = (period.number - 1) / 3 + 1
        let quarterStart = year.periods[(quarter - 1) * 3].start
        let (week, isBoundary) = fiscalWeek(of: date, in: year)
        return FiscalInfo(fiscalYear: year, quarter: quarter, dayOfQuarter: date.days(since: quarterStart) + 1,
                          period: period, dayOfYear: date.days(since: year.start) + 1,
                          week: week, isWeekYearBoundary: isBoundary)
    }

    // MARK: Private

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var endMonth: Int { startMonth == 1 ? 12 : startMonth - 1 }

    /// ISO weekday of a week's last day (Saturday for Sunday weeks).
    private var weekEnd: Int { weekStart == 1 ? 7 : weekStart - 1 }

    private func endYear(_ startYear: Int) -> Int { startMonth == 1 ? startYear : startYear + 1 }

    private func yearName(_ startYear: Int) -> String {
        let endYear = endYear(startYear)
        let short = endYear % 100 < 10 ? "0\(endYear % 100)" : "\(endYear % 100)"
        switch naming {
        case .short: return "FY" + short
        case .long: return startMonth == 1 ? "FY\(startYear)" : "FY\(startYear)-" + short
        }
    }

    private func firstDay(_ startYear: Int) -> CivilDate {
        switch basis {
        case .calendarMonths: CivilDate(startYear, startMonth, 1)
        case .weekBased: lastDay(startYear - 1).adding(days: 1)
        }
    }

    private func lastDay(_ startYear: Int) -> CivilDate {
        let year = endYear(startYear)
        let monthEnd = CivilDate(year, endMonth, PeriodEngine.daysInMonth(year, endMonth))
        switch basis {
        case .calendarMonths:
            return monthEnd
        case .weekBased(_, let rule):
            let back = (monthEnd.isoWeekday - weekEnd + 7) % 7          // days since the last week end
            switch rule {
            case .lastInMonth: return monthEnd.adding(days: -back)
            case .nearestMonthEnd: return back <= 3 ? monthEnd.adding(days: -back) : monthEnd.adding(days: 7 - back)
            }
        }
    }

    private func startYear(containing date: CivilDate) -> Int {
        var guess = date.month >= startMonth ? date.year : date.year - 1
        // Week-based years can start a few days before or after the 1st of the month.
        if date < firstDay(guess) { guess -= 1 }
        if date > lastDay(guess) { guess += 1 }
        return guess
    }

    /// The first day of the calendar week containing `date`.
    private func weekStartDate(containing date: CivilDate) -> CivilDate {
        date.adding(days: -((date.isoWeekday - weekStart + 7) % 7))
    }

    private func fiscalWeek(of date: CivilDate, in year: FiscalYear) -> (FiscalWeek, isBoundary: Bool) {
        switch basis {
        case .weekBased:
            let number = date.days(since: year.start) / 7 + 1
            let start = year.start.adding(days: (number - 1) * 7)
            return (FiscalWeek(fiscalYearName: year.name, number: number, start: start, end: start.adding(days: 6)), false)

        case .calendarMonths(let rule):
            let week1Start = weekStartDate(containing: year.start)
            let number = date.days(since: week1Start) / 7 + 1
            let calendarWeekStart = week1Start.adding(days: (number - 1) * 7)

            switch rule {
            case .containsYearStart:
                // Days that share a week with next year's start are next year's week 1.
                let next = fiscalYear(startingIn: year.startYear + 1)
                let nextWeek1Start = weekStartDate(containing: next.start)
                if date >= nextWeek1Start {
                    return (FiscalWeek(fiscalYearName: next.name, number: 1, start: nextWeek1Start,
                                       end: nextWeek1Start.adding(days: 6)), true)
                }
                return (FiscalWeek(fiscalYearName: year.name, number: number, start: calendarWeekStart,
                                   end: calendarWeekStart.adding(days: 6)), false)

            case .startsOnYearStart:
                // Partial first and last weeks are clipped to the year.
                return (FiscalWeek(fiscalYearName: year.name, number: number,
                                   start: max(calendarWeekStart, year.start),
                                   end: min(calendarWeekStart.adding(days: 6), year.end)), false)
            }
        }
    }
}

public struct FiscalYear: Hashable, Sendable {
    /// The calendar year of the nominal start month (2026 for FY27 and for FY2026-27).
    public let startYear: Int
    public let name: String
    public let start: CivilDate
    public let end: CivilDate
    /// 52 or 53 for week-based years; `nil` for calendar-month years.
    public let weekCount: Int?
    /// Always 12.
    public let periods: [FiscalPeriod]

    public var dayCount: Int { end.days(since: start) + 1 }
}

public struct FiscalPeriod: Hashable, Sendable {
    public let number: Int
    /// `P7 Oct` for calendar months, `P9` for week-based.
    public let name: String
    public let start: CivilDate
    public let end: CivilDate
    /// Weeks in the period for week-based years; `nil` for calendar months.
    public let weeks: Int?
}

public struct FiscalWeek: Hashable, Sendable {
    /// Usually the date's fiscal year; the next one at a week-year boundary (decision A).
    public let fiscalYearName: String
    public let number: Int
    public let start: CivilDate
    public let end: CivilDate
}

public struct FiscalInfo: Hashable, Sendable {
    public let fiscalYear: FiscalYear
    public let quarter: Int
    public let dayOfQuarter: Int
    public let period: FiscalPeriod
    /// Day of the fiscal year, 1-based.
    public let dayOfYear: Int
    public let week: FiscalWeek
    /// True when `week` belongs to a different fiscal year than the date (shown as a note).
    public let isWeekYearBoundary: Bool
}

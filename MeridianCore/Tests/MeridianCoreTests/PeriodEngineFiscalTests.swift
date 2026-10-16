import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § PeriodEngine — fiscal, plus decision A (docs/decisions.md).
@Suite("PeriodEngine fiscal")
struct PeriodEngineFiscalTests {

    /// India FY: calendar months from 1 April, Monday weeks, named FY27.
    static func india(_ rule: FiscalProfile.Week1Rule) -> FiscalProfile {
        FiscalProfile(name: "India FY", startMonth: 4, weekStart: 1,
                      basis: .calendarMonths(week1: rule), naming: .short)
    }

    /// Retail 4-4-5: from February, Sunday–Saturday weeks, year ends on the Saturday
    /// nearest 31 January, 53rd week in the last period, named FY2026-27.
    static let retail = FiscalProfile(name: "Retail 4-4-5", startMonth: 2, weekStart: 7,
                                      basis: .weekBased(pattern: .p445, yearEnd: .nearestMonthEnd),
                                      naming: .long)

    // MARK: India FY

    @Test("FY27 is Wed 1 Apr 2026 – Wed 31 Mar 2027, 365 days")
    func fy27() {
        let year = Self.india(.containsYearStart).fiscalYear(startingIn: 2026)
        #expect(year.name == "FY27")
        #expect(year.start == CivilDate(2026, 4, 1))
        #expect(year.end == CivilDate(2027, 3, 31))
        #expect(year.dayCount == 365)
    }

    @Test("India FY rows", arguments: [
        (CivilDate(2026, 10, 16), "FY27", 3, "P7 Oct", 199, 29),
        (CivilDate(2025, 12, 29), "FY26", 3, "P9 Dec", 273, 40),
        (CivilDate(2026, 10, 26), "FY27", 3, "P7 Oct", 209, 31),
        (CivilDate(2026, 11, 1), "FY27", 3, "P8 Nov", 215, 31),
    ])
    func indiaRows(date: CivilDate, fy: String, quarter: Int, period: String, dayOfFY: Int, week: Int) {
        for rule in [FiscalProfile.Week1Rule.containsYearStart, .startsOnYearStart] {
            let info = Self.india(rule).info(for: date)
            #expect(info.fiscalYear.name == fy)
            #expect(info.quarter == quarter)
            #expect(info.period.name == period)
            #expect(info.dayOfYear == dayOfFY)
            #expect(info.week.number == week, "rule \(rule)")
            #expect(info.week.fiscalYearName == fy)
        }
    }

    @Test("Day of quarter: 16 on 16 Oct 2026, 90 on 29 Dec 2025")
    func indiaDayOfQuarter() {
        #expect(Self.india(.containsYearStart).info(for: CivilDate(2026, 10, 16)).dayOfQuarter == 16)
        #expect(Self.india(.containsYearStart).info(for: CivilDate(2025, 12, 29)).dayOfQuarter == 90)
    }

    @Test("Week 1 of FY27 under each rule")
    func week1Ranges() {
        let containing = Self.india(.containsYearStart).info(for: CivilDate(2026, 4, 1)).week
        #expect(containing.number == 1)
        #expect(containing.start == CivilDate(2026, 3, 30))
        #expect(containing.end == CivilDate(2026, 4, 5))

        let startsOn = Self.india(.startsOnYearStart).info(for: CivilDate(2026, 4, 1)).week
        #expect(startsOn.number == 1)
        #expect(startsOn.start == CivilDate(2026, 4, 1))
        #expect(startsOn.end == CivilDate(2026, 4, 5))
        #expect(startsOn.end.days(since: startsOn.start) + 1 == 5)
    }

    @Test("2026-W44 straddles P7 (26–31 Oct) and P8 (1 Nov)")
    func w44Straddles() throws {
        let week = try PeriodEngine.parseISOWeek("2026-W44")
        let profile = Self.india(.containsYearStart)
        #expect(profile.info(for: week.start).period.name == "P7 Oct")
        #expect(profile.info(for: CivilDate(2026, 10, 31)).period.name == "P7 Oct")
        #expect(profile.info(for: week.end).period.name == "P8 Nov")
    }

    /// Decision A: FY30 starts Sun 1 Apr 2029. Wed 28 Mar 2029 is FY29 by month.
    @Test("Week-1 rules give different numbers before a Sunday year start")
    func week1RulesDiffer() {
        let date = CivilDate(2029, 3, 28)

        let containing = Self.india(.containsYearStart).info(for: date)
        #expect(containing.fiscalYear.name == "FY29")
        #expect(containing.period.name == "P12 Mar")
        #expect(containing.week.fiscalYearName == "FY30")
        #expect(containing.week.number == 1)
        #expect(containing.week.start == CivilDate(2029, 3, 26))
        #expect(containing.isWeekYearBoundary)

        let startsOn = Self.india(.startsOnYearStart).info(for: date)
        #expect(startsOn.fiscalYear.name == "FY29")
        #expect(startsOn.week.fiscalYearName == "FY29")
        #expect(startsOn.week.number == 53)
        #expect(startsOn.week.end == CivilDate(2029, 3, 31))      // clipped at the year end
        #expect(startsOn.isWeekYearBoundary == false)

        // Under "containing", FY29's last week is W52, ending the Sunday before.
        let lastWeek = Self.india(.containsYearStart).info(for: CivilDate(2029, 3, 25)).week
        #expect(lastWeek.fiscalYearName == "FY29")
        #expect(lastWeek.number == 52)
    }

    // MARK: Retail 4-4-5

    @Test("Retail fiscal years", arguments: [
        (2025, "FY2025-26", CivilDate(2025, 2, 2), CivilDate(2026, 1, 31), 52),
        (2026, "FY2026-27", CivilDate(2026, 2, 1), CivilDate(2027, 1, 30), 52),
        (2027, "FY2027-28", CivilDate(2027, 1, 31), CivilDate(2028, 1, 29), 52),
        (2028, "FY2028-29", CivilDate(2028, 1, 30), CivilDate(2029, 2, 3), 53),
    ])
    func retailYears(startYear: Int, name: String, start: CivilDate, end: CivilDate, weeks: Int) {
        let year = Self.retail.fiscalYear(startingIn: startYear)
        #expect(year.name == name)
        #expect(year.start == start)
        #expect(year.start.isoWeekday == 7)        // Sunday
        #expect(year.end == end)
        #expect(year.end.isoWeekday == 6)          // Saturday
        #expect(year.weekCount == weeks)
        #expect(year.periods.count == 12)
    }

    @Test("53-week year: the extra week goes to P12 (6 weeks)")
    func fiftyThreeWeeks() {
        let periods = Self.retail.fiscalYear(startingIn: 2028).periods
        #expect(periods.map(\.weeks) == [4, 4, 5, 4, 4, 5, 4, 4, 5, 4, 4, 6])
        #expect(periods.last?.end == CivilDate(2029, 2, 3))
    }

    @Test("2026-10-16 → FY2026-27 Q3, P9 (Sun 27 Sep – Sat 31 Oct 2026), week 37")
    func retailOct16() {
        let info = Self.retail.info(for: CivilDate(2026, 10, 16))
        #expect(info.fiscalYear.name == "FY2026-27")
        #expect(info.quarter == 3)
        #expect(info.period.number == 9)
        #expect(info.period.name == "P9")
        #expect(info.period.start == CivilDate(2026, 9, 27))
        #expect(info.period.end == CivilDate(2026, 10, 31))
        #expect(info.week.number == 37)
    }

    @Test("A date on the retail year boundary belongs to the year that contains it")
    func retailBoundary() {
        #expect(Self.retail.info(for: CivilDate(2027, 1, 30)).fiscalYear.name == "FY2026-27")
        #expect(Self.retail.info(for: CivilDate(2027, 1, 31)).fiscalYear.name == "FY2027-28")
        #expect(Self.retail.info(for: CivilDate(2027, 1, 31)).week.number == 1)
    }

    @Test("Week-based years tile time with whole weeks, for every pattern and year-end rule",
          arguments: [FiscalProfile.Pattern.p445, .p454, .p544],
          [FiscalProfile.YearEndRule.lastInMonth, .nearestMonthEnd])
    func weekBasedInvariants(pattern: FiscalProfile.Pattern, rule: FiscalProfile.YearEndRule) {
        let profile = FiscalProfile(name: "Test", startMonth: 2, weekStart: 7,
                                    basis: .weekBased(pattern: pattern, yearEnd: rule), naming: .long)
        var problems: [String] = []
        for startYear in 1900...2199 {
            let year = profile.fiscalYear(startingIn: startYear)
            let next = profile.fiscalYear(startingIn: startYear + 1)
            if year.start.isoWeekday != 7 || year.end.isoWeekday != 6 { problems.append("\(year.name) weekdays") }
            if next.start != year.end.adding(days: 1) { problems.append("\(year.name) gap") }
            if ![52, 53].contains(year.weekCount) { problems.append("\(year.name) weeks") }
            if year.periods.compactMap(\.weeks).reduce(0, +) != year.weekCount { problems.append("\(year.name) periods") }
            if year.periods.last?.end != year.end { problems.append("\(year.name) last period") }
            if rule == .lastInMonth, year.end.month != 1 || year.end.adding(days: 7).month == 1 {
                problems.append("\(year.name) not the last Saturday of January")
            }
            if rule == .nearestMonthEnd, abs(year.end.days(since: CivilDate(year.end.year > startYear ? startYear + 1 : startYear, 1, 31))) > 3 {
                problems.append("\(year.name) not nearest 31 Jan")
            }
        }
        #expect(problems.isEmpty, "\(problems.prefix(5))")
    }

    // MARK: Naming

    @Test("Naming: FY27 and FY2026-27; a January start is just the calendar year")
    func naming() {
        let longIndia = FiscalProfile(name: "India", startMonth: 4, weekStart: 1,
                                      basis: .calendarMonths(week1: .containsYearStart), naming: .long)
        #expect(longIndia.fiscalYear(startingIn: 2026).name == "FY2026-27")
        let january = FiscalProfile(name: "Calendar", startMonth: 1, weekStart: 1,
                                    basis: .calendarMonths(week1: .containsYearStart), naming: .long)
        #expect(january.fiscalYear(startingIn: 2026).name == "FY2026")
        let januaryShort = FiscalProfile(name: "Calendar", startMonth: 1, weekStart: 1,
                                         basis: .calendarMonths(week1: .containsYearStart), naming: .short)
        #expect(januaryShort.fiscalYear(startingIn: 2026).name == "FY26")
    }
}

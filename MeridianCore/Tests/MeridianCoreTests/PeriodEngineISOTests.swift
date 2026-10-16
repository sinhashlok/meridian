import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § PeriodEngine — ISO.
@Suite("PeriodEngine ISO")
struct PeriodEngineISOTests {

    @Test("ISO week, weekday, day of year and quarter", arguments: [
        (CivilDate(2026, 10, 15), "2026-W42", 4, 288, 4),
        (CivilDate(2026, 10, 16), "2026-W42", 5, 289, 4),
        (CivilDate(2025, 12, 29), "2026-W01", 1, 363, 4),     // week-year differs from the year
        (CivilDate(2027, 1, 1), "2026-W53", 5, 1, 1),         // ditto, the other direction
        (CivilDate(2026, 10, 25), "2026-W43", 7, 298, 4),
    ])
    func rows(date: CivilDate, week: String, weekday: Int, dayOfYear: Int, quarter: Int) {
        let info = PeriodEngine.info(for: date)
        #expect(info.isoWeek.text == week)
        #expect(info.isoWeekday == weekday)
        #expect(info.dayOfYear == dayOfYear)
        #expect(info.quarter == quarter)
    }

    @Test("2026-10-16: day 289 of 365, Q4 day 16 of 92, 76 days left")
    func oct16Detail() {
        let info = PeriodEngine.info(for: CivilDate(2026, 10, 16))
        #expect(info.daysInYear == 365)
        #expect(info.dayOfQuarter == 16)
        #expect(info.daysInQuarter == 92)
        #expect(info.daysLeftInYear == 76)
    }

    @Test("2025-12-29: day 363 of 365, Q4 day 90 of 92, 2 days left")
    func dec29Detail() {
        let info = PeriodEngine.info(for: CivilDate(2025, 12, 29))
        #expect(info.daysInYear == 365)
        #expect(info.dayOfQuarter == 90)
        #expect(info.daysInQuarter == 92)
        #expect(info.daysLeftInYear == 2)
    }

    @Test("Weeks per ISO year", arguments: [(2025, 52), (2026, 53), (2027, 52)])
    func weeksPerYear(year: Int, weeks: Int) {
        #expect(PeriodEngine.weeksInISOYear(year) == weeks)
    }

    @Test("2026-W44 is Mon 26 Oct – Sun 1 Nov 2026, days 299–305")
    func week44() throws {
        let week = try PeriodEngine.parseISOWeek("2026-W44")
        #expect(week.start == CivilDate(2026, 10, 26))
        #expect(week.end == CivilDate(2026, 11, 1))
        #expect(PeriodEngine.info(for: week.start).dayOfYear == 299)
        #expect(PeriodEngine.info(for: week.end).dayOfYear == 305)
        // The ISO week of each date in a week agrees with the parsed week.
        #expect(PeriodEngine.info(for: CivilDate(2026, 10, 28)).weekRange == week)
    }

    @Test("2026-W53 exists, 2026-W54 does not")
    func weekBounds() throws {
        let w53 = try PeriodEngine.parseISOWeek("2026-W53")
        #expect(w53.start == CivilDate(2026, 12, 28))
        #expect(w53.end == CivilDate(2027, 1, 3))
        #expect(throws: PeriodError.weekOutOfRange(year: 2026, weeks: 53)) {
            try PeriodEngine.parseISOWeek("2026-W54")
        }
        #expect(throws: PeriodError.weekOutOfRange(year: 2027, weeks: 52)) {
            try PeriodEngine.parseISOWeek("2027-W53")
        }
    }

    @Test("Malformed ISO weeks throw", arguments: ["2026-44", "2026-W4", "W44", "2026-W00", ""])
    func malformedWeek(input: String) {
        #expect(throws: (any Error).self) { try PeriodEngine.parseISOWeek(input) }
    }

    @Test("Weeks are always written YYYY-Www")
    func weekText() {
        #expect(ISOWeek(year: 2026, week: 1).text == "2026-W01")
        #expect(ISOWeek(year: 2026, week: 44).text == "2026-W44")
    }

    @Test("ISO week agrees with Foundation's ISO 8601 calendar for every day 1900–2199")
    func isoWeekSweep() {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = .gmt
        var mismatches = 0
        var date = CivilDate(1900, 1, 1)
        while date.year < 2200 {
            let instant = Date(timeIntervalSince1970: Double(date.daysSinceEpoch) * 86_400)
            let parts = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: instant)
            let ours = PeriodEngine.isoWeek(of: date)
            if ours.year != parts.yearForWeekOfYear || ours.week != parts.weekOfYear { mismatches += 1 }
            date = date.adding(days: 1)
        }
        #expect(mismatches == 0)
    }

    @Test("Leap year has 366 days and a 91-day Q1")
    func leapYear() {
        let info = PeriodEngine.info(for: CivilDate(2028, 2, 29))
        #expect(info.daysInYear == 366)
        #expect(info.dayOfYear == 60)
        #expect(info.daysInQuarter == 91)
    }
}

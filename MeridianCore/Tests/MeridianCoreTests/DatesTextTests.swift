import Foundation
import Testing
@testable import MeridianCore

/// Tools › Dates wording and the fiscal profile sheet (boards DatesToday,
/// DatesYearBoundary, DatesReverse, DatesInvalid, DatesNoProfile, FiscalEditor,
/// FiscalEditorMonths; spec §4.6; decisions Y, Z, AA). Values from fixtures.md and
/// checked with Python.
@Suite("Dates text")
struct DatesTextTests {
    static let india = FiscalProfile(name: "India FY", startMonth: 4, weekStart: 1,
                                     basis: .calendarMonths(week1: .containsYearStart), naming: .short)
    static let retail = FiscalProfile(name: "Retail 4-4-5", startMonth: 2, weekStart: 7,
                                      basis: .weekBased(pattern: .p445, yearEnd: .nearestMonthEnd), naming: .long)
    static let today = CivilDate(2026, 10, 16)

    static func result(_ text: String, _ profile: FiscalProfile? = india) throws -> DatesResult {
        guard case .result(let result) = DatesText.read(text, profile: profile, today: today) else {
            Issue.record("\(text) gave no result")
            throw CancellationError()
        }
        return result
    }

    static func problem(_ text: String, _ profile: FiscalProfile? = india) throws -> DatesProblem {
        guard case .problem(let problem) = DatesText.read(text, profile: profile, today: today) else {
            Issue.record("\(text) gave no problem")
            throw CancellationError()
        }
        return problem
    }

    static func rows(_ section: DatesSection) -> [String] { section.rows.map { "\($0.label)=\($0.value)" } }

    // MARK: A date

    @Test("Today, with the India FY profile (board DatesToday)")
    func today() throws {
        let result = try Self.result("2026-10-16")
        #expect(result.inputLabel == "Date · today")
        #expect(result.notesBefore.isEmpty && result.notesAfter.isEmpty)
        #expect(result.sections.map(\.title) == ["Date · Fri 16 Oct 2026", "Fiscal · India FY"])
        #expect(Self.rows(result.sections[0]) == [
            "ISO week=2026-W42", "ISO weekday=Fri · 5", "Week=Mon 12 – Sun 18 Oct", "Day of year=289 of 365",
            "Quarter=Q4 · day 16 of 92", "Days left in year=76",
        ])
        #expect(Self.rows(result.sections[1]) == [
            "Fiscal year=FY27", "Quarter=Q3 · day 16 of 92", "Period=P7 · Oct", "Week of fiscal year=29",
            "Day of fiscal year=199 of 365",
        ])
        #expect(result.sections[0].rows[0].copyText == "2026-W42")
        #expect(!result.needsProfile)
    }

    @Test("ISO week-year boundary note (board DatesYearBoundary)")
    func yearBoundary() throws {
        let result = try Self.result("2025-12-29")
        #expect(result.inputLabel == "Date")
        #expect(result.notesBefore == [DatesNote(
            lead: "ISO week-year differs from the calendar year.",
            text: "Mon 29 Dec 2025 is in week 1 of ISO year 2026, because that week's Thursday (Thu 1 Jan 2026) is in 2026.")])
        #expect(Self.rows(result.sections[0]) == [
            "ISO week=2026-W01", "ISO weekday=Mon · 1", "Week=Mon 29 Dec – Sun 4 Jan", "Day of year=363 of 365",
            "Quarter=Q4 · day 90 of 92", "Days left in year=2",
        ])
        #expect(Self.rows(result.sections[1]) == [
            "Fiscal year=FY26", "Quarter=Q3 · day 90 of 92", "Period=P9 · Dec", "Week of fiscal year=40",
            "Day of fiscal year=273 of 365",
        ])
    }

    @Test("Week-based fiscal rows (Retail 4-4-5)")
    func retailRows() throws {
        let result = try Self.result("2026-10-16", Self.retail)
        #expect(Self.rows(result.sections[1]) == [
            "Fiscal year=FY2026-27", "Quarter=Q3 · day 76 of 91", "Period=P9 · Sun 27 Sep – Sat 31 Oct",
            "Week of fiscal year=37", "Day of fiscal year=258 of 364",
        ])
    }

    @Test("No profile: date rows only, and the add-a-calendar card (board DatesNoProfile)")
    func noProfile() throws {
        let result = try Self.result("2026-10-16", nil)
        #expect(result.sections.map(\.title) == ["Date · Fri 16 Oct 2026"])
        #expect(result.needsProfile)
    }

    // MARK: An ISO week

    @Test("ISO week across two fiscal periods (board DatesReverse)")
    func isoWeek() throws {
        let result = try Self.result("2026-W44")
        #expect(result.inputLabel == "ISO week")
        #expect(result.sections.map(\.title) == ["ISO week 44 · 2026", "Fiscal · India FY"])
        #expect(Self.rows(result.sections[0]) == [
            "Week=Mon 26 Oct – Sun 1 Nov 2026", "Days of year=299–305 of 365", "Quarter=Q4", "Months=Oct · Nov",
        ])
        #expect(Self.rows(result.sections[1]) == [
            "Fiscal year=FY27", "Quarter=Q3", "Period=P7 Oct (Mon–Sat)\nP8 Nov (Sun)", "Week of fiscal year=31",
            "Days of fiscal year=209–215 of 365",
        ])
        #expect(result.notesAfter == [DatesNote(lead: nil,
            text: "This week spans two fiscal periods: Mon 26 – Sat 31 Oct are in P7, Sun 1 Nov is in P8.")])
    }

    @Test("Week 53 crosses the year end")
    func week53() throws {
        let result = try Self.result("2026-W53")
        #expect(Self.rows(result.sections[0]) == [
            "Week=Mon 28 Dec 2026 – Sun 3 Jan 2027", "Days of year=362–365 of 365 · 1–3 of 365", "Quarter=Q4 · Q1",
            "Months=Dec · Jan",
        ])
        #expect(result.notesAfter.contains(DatesNote(lead: nil, text: "2026 has 53 ISO weeks; this is the extra one.")))
    }

    @Test("Week 54 doesn't exist: suggest the last week (board DatesInvalid)")
    func week54() throws {
        let problem = try Self.problem("2026-W54")
        #expect(problem.inputLabel == "ISO week")
        #expect(problem.title == "2026 has 53 ISO weeks")
        #expect(problem.detail == "There is no week 54. The last week is 2026-W53: Mon 28 Dec 2026 – Sun 3 Jan 2027.")
        #expect(problem.fix == DatesFix(label: "Use 2026-W53", input: "2026-W53"))
        #expect(try Self.problem("2026-W00").fix == DatesFix(label: "Use 2026-W01", input: "2026-W01"))
    }

    // MARK: A fiscal period (decision AA)

    @Test("Fiscal quarter, period and year inputs, in any order and case")
    func fiscalInputs() throws {
        let quarter = try Self.result("Q3 FY27")
        #expect(quarter.inputLabel == "Fiscal period")
        #expect(quarter.sections.map(\.title) == ["Q3 FY27 · India FY"])
        #expect(Self.rows(quarter.sections[0]) == [
            "Dates=Thu 1 Oct – Thu 31 Dec 2026", "Days=92", "Periods=P7 Oct · P8 Nov · P9 Dec",
            "ISO weeks=2026-W40 – 2026-W53",
        ])
        #expect(try Self.result("fy27 q3") == quarter)
        let period = try Self.result("P7 FY27")
        #expect(Self.rows(period.sections[0]) == [
            "Dates=Thu 1 – Sat 31 Oct 2026", "Days=31", "ISO weeks=2026-W40 – 2026-W44",
        ])
        let year = try Self.result("FY2026-27")
        #expect(year.sections.map(\.title) == ["FY27 · India FY"])
        #expect(Self.rows(year.sections[0]).prefix(2) == ["Dates=Wed 1 Apr 2026 – Wed 31 Mar 2027", "Days=365"])
        let retailYear = try Self.result("FY2026-27", Self.retail)
        #expect(Self.rows(retailYear.sections[0]).contains("Weeks=52"))
    }

    @Test("Fiscal input without a profile, and other bad input")
    func badInput() throws {
        let missing = try Self.problem("Q3 FY27", nil)
        #expect(missing.title == "Fiscal periods need a fiscal calendar")
        #expect(missing.needsProfile)
        #expect(try Self.problem("hello").title == "Not a date, ISO week or fiscal period")
        #expect(try Self.problem("hello").detail == "Try 2026-10-16, 2026-W42 or Q3 FY27.")
        let february = try Self.problem("2026-02-30")
        #expect(february.title == "30 Feb 2026 doesn't exist")
        #expect(february.detail == "February 2026 has 28 days.")
        #expect(try Self.problem("Q5 FY27").title == "Quarters run Q1–Q4")
        #expect(DatesText.read("  ", profile: nil, today: Self.today) == .empty)
    }

    // MARK: Fiscal editor previews

    @Test("Week 1 previews for calendar-month profiles (board FiscalEditorMonths)")
    func week1Previews() {
        let previews = FiscalEditorText.week1Previews(Self.india, today: Self.today)
        #expect(previews.containing == "FY27: Mon 30 Mar – Sun 5 Apr 2026")
        #expect(previews.startsOn == "FY27: Wed 1 – Sun 5 Apr (5 days)")
    }

    @Test("This-year preview")
    func thisYear() {
        #expect(FiscalEditorText.thisYear(Self.india, today: Self.today) == FiscalPreview(
            title: "FY27 · 12 months · 365 days", range: "Wed 1 Apr 2026 – Wed 31 Mar 2027",
            today: "Today: Q3 · P7 Oct · week 29"))
        #expect(FiscalEditorText.thisYear(Self.retail, today: Self.today) == FiscalPreview(
            title: "FY2026-27 · 52 weeks", range: "Sun 1 Feb 2026 – Sat 30 Jan 2027",
            today: "Today: Q3 · P9 (Sun 27 Sep – Sat 31 Oct) · week 37"))
    }

    @Test("Next 53-week year, year-end and naming labels")
    func editorLabels() {
        #expect(FiscalEditorText.next53WeekYear(Self.retail, today: Self.today) == DatesNote(
            lead: "FY2028-29 has 53 weeks",
            text: "(Sun 30 Jan 2028 – Sat 3 Feb 2029). That year P12 has 6 weeks instead of 5."))
        #expect(FiscalEditorText.next53WeekYear(Self.india, today: Self.today) == nil)
        #expect(FiscalEditorText.yearEndLabel(.nearestMonthEnd, startMonth: 2, weekStart: 7) == "Sat nearest 31 Jan")
        #expect(FiscalEditorText.yearEndLabel(.lastInMonth, startMonth: 2, weekStart: 7) == "Last Sat of Jan")
        #expect(FiscalEditorText.yearEndLabel(.lastInMonth, startMonth: 3, weekStart: 1) == "Last Sun of Feb")
        #expect(FiscalEditorText.yearNames(startMonth: 4, today: Self.today) == (short: "FY27", long: "FY2026-27"))
        #expect(FiscalEditorText.yearNames(startMonth: 1, today: Self.today) == (short: "FY26", long: "FY2026"))
    }

    // MARK: Saving profiles (decisions Y, AG)

    @Test("Profiles round-trip through JSON")
    func codable() throws {
        for profile in [Self.india, Self.retail] {
            let data = try JSONEncoder().encode(profile)
            #expect(try JSONDecoder().decode(FiscalProfile.self, from: data) == profile)
        }
    }

    @Test("Profile list: at most 3, exactly one active while any exist")
    func profileList() {
        var list = FiscalProfileList()
        #expect(list.active == nil)
        let added = [list.add(Self.india), list.add(Self.retail), list.add(FiscalProfile.presets[1]), list.add(Self.india)]
        #expect(added == [true, true, true, false])                   // a fourth is refused
        #expect(list.active == Self.india)                          // the first added; adding doesn't switch
        #expect(list.profiles.count == 3)
        list.activate(at: 1)
        #expect(list.active == Self.retail)
        list.remove(at: 1)                                           // removing the active one
        #expect(list.active == Self.india)
        list.remove(at: 0)
        list.remove(at: 0)
        #expect(list.profiles.isEmpty && list.active == nil)
        #expect(FiscalProfile.presets.map(\.name) == ["India FY", "US federal", "Retail 4-4-5"])
    }
}

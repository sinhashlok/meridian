import Foundation

/// One Dates row with its copy button: `ISO week` · `2026-W42`. `value` may hold two
/// lines (a week split across periods).
public struct DatesRow: Equatable, Sendable {
    public let label: String
    public let value: String
    public let copyText: String
}

/// `Date · Fri 16 Oct 2026` or `Fiscal · India FY` and its rows.
public struct DatesSection: Equatable, Sendable {
    public let title: String
    public let rows: [DatesRow]
}

/// An info note; `lead` is the bold first sentence, if any.
public struct DatesNote: Equatable, Sendable {
    public let lead: String?
    public let text: String
}

/// `Use 2026-W53`: a button that replaces the input.
public struct DatesFix: Equatable, Sendable {
    public let label: String
    public let input: String
}

public struct DatesResult: Equatable, Sendable {
    /// Beside the input: `Date · today`, `Date`, `ISO week`, `Fiscal period`.
    public let inputLabel: String
    public let notesBefore: [DatesNote]
    public let sections: [DatesSection]
    public let notesAfter: [DatesNote]
    /// No fiscal profile: show the "Add a fiscal calendar" card.
    public let needsProfile: Bool
}

public struct DatesProblem: Equatable, Sendable {
    public let inputLabel: String
    public let title: String
    public let detail: String
    public let fix: DatesFix?
    /// A fiscal input with no profile: offer to add one.
    public let needsProfile: Bool
}

public enum DatesReading: Equatable, Sendable {
    case empty
    case result(DatesResult)
    case problem(DatesProblem)
}

/// Tools › Dates (spec §4.6): one input that takes a date (`2026-10-16`), an ISO week
/// (`2026-W44`) or a fiscal period (`Q3 FY27`, decision AA). Date-only maths.
public enum DatesText {
    public static func read(_ text: String, profile: FiscalProfile?, today: CivilDate) -> DatesReading {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }

        if let match = trimmed.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/) {
            guard let date = CivilDate(iso: trimmed) else {
                return .problem(missingDate(year: Int(match.output.1)!, month: Int(match.output.2)!, day: Int(match.output.3)!))
            }
            return .result(dateResult(date, profile: profile, today: today))
        }
        if let match = trimmed.wholeMatch(of: /(\d{4})-?[Ww](\d{1,2})/) {
            return weekReading(year: Int(match.output.1)!, week: Int(match.output.2)!, profile: profile)
        }
        if trimmed.uppercased().contains("FY") {
            return fiscalReading(trimmed, profile: profile)
        }
        return .problem(DatesProblem(inputLabel: "", title: "Not a date, ISO week or fiscal period",
                                     detail: "Try 2026-10-16, 2026-W42 or Q3 FY27.", fix: nil, needsProfile: false))
    }

    // MARK: A date

    private static func dateResult(_ date: CivilDate, profile: FiscalProfile?, today: CivilDate) -> DatesResult {
        let info = PeriodEngine.info(for: date)
        var before: [DatesNote] = []
        if info.isoWeek.year != date.year {
            let thursday = date.adding(days: 4 - date.isoWeekday)
            before.append(DatesNote(
                lead: "ISO week-year differs from the calendar year.",
                text: "\(full(date)) is in week \(info.isoWeek.week) of ISO year \(info.isoWeek.year), because that "
                    + "week's Thursday (\(full(thursday))) is in \(thursday.year)."))
        }
        var sections = [DatesSection(title: "Date · \(full(date))", rows: [
            row("ISO week", info.isoWeek.text),
            row("ISO weekday", "\(date.weekdayText) · \(date.isoWeekday)"),
            row("Week", range(info.weekRange.start, info.weekRange.end, withYear: false)),
            row("Day of year", "\(info.dayOfYear) of \(info.daysInYear)"),
            row("Quarter", "Q\(info.quarter) · day \(info.dayOfQuarter) of \(info.daysInQuarter)"),
            row("Days left in year", "\(info.daysLeftInYear)"),
        ])]

        var after: [DatesNote] = []
        if let profile {
            let fiscal = profile.info(for: date)
            let year = fiscal.fiscalYear
            let quarterPeriods = year.periods[(fiscal.quarter - 1) * 3...(fiscal.quarter - 1) * 3 + 2]
            let daysInQuarter = quarterPeriods.last!.end.days(since: quarterPeriods.first!.start) + 1
            let week = fiscal.isWeekYearBoundary ? "\(fiscal.week.number) (\(fiscal.week.fiscalYearName))" : "\(fiscal.week.number)"
            sections.append(DatesSection(title: "Fiscal · \(profile.name)", rows: [
                row("Fiscal year", year.name),
                row("Quarter", "Q\(fiscal.quarter) · day \(fiscal.dayOfQuarter) of \(daysInQuarter)"),
                row("Period", periodValue(fiscal.period)),
                row("Week of fiscal year", week),
                row("Day of fiscal year", "\(fiscal.dayOfYear) of \(year.dayCount)"),
            ]))
            if fiscal.isWeekYearBoundary {
                after.append(DatesNote(lead: nil, text: "\(full(date)) is in \(year.name) by month, but its week is "
                                       + "week 1 of \(fiscal.week.fiscalYearName)."))
            }
            if let note = fiftyThreeWeekNote(year) { after.append(note) }
        }
        return DatesResult(inputLabel: date == today ? "Date · today" : "Date", notesBefore: before,
                           sections: sections, notesAfter: after, needsProfile: profile == nil)
    }

    // MARK: An ISO week

    private static func weekReading(year: Int, week: Int, profile: FiscalProfile?) -> DatesReading {
        guard (1...9998).contains(year) else {
            return .problem(DatesProblem(inputLabel: "ISO week", title: "Years run 0001–9998 here",
                                         detail: "Try a week like 2026-W42.", fix: nil, needsProfile: false))
        }
        let weeks = PeriodEngine.weeksInISOYear(year)
        guard (1...weeks).contains(week) else {
            let nearest = week < 1 ? 1 : weeks
            let text = ISOWeek(year: year, week: nearest).text
            let span = PeriodEngine.range(of: ISOWeek(year: year, week: nearest))
            let which = week < 1 ? "first" : "last"
            return .problem(DatesProblem(
                inputLabel: "ISO week", title: "\(year) has \(weeks) ISO weeks",
                detail: "There is no week \(week). The \(which) week is \(text): \(range(span.start, span.end, withYear: true)).",
                fix: DatesFix(label: "Use \(text)", input: text), needsProfile: false))
        }

        let span = PeriodEngine.range(of: ISOWeek(year: year, week: week))
        let days = (0..<7).map { span.start.adding(days: $0) }
        var sections = [DatesSection(title: "ISO week \(week) · \(year)", rows: [
            row("Week", range(span.start, span.end, withYear: true)),
            row("Days of year", dayRanges(days.map { date in
                let info = PeriodEngine.info(for: date)
                return (date.year, info.dayOfYear, info.daysInYear)
            })),
            row("Quarter", distinct(days.map { "Q\(PeriodEngine.info(for: $0).quarter)" })),
            row("Months", distinct(days.map { monthNames[$0.month - 1] })),
        ])]

        var after: [DatesNote] = []
        if let profile {
            let infos = days.map { profile.info(for: $0) }
            let groups = runs(of: zip(days, infos).map { ($0, $1.period) })
            let period = groups.count == 1
                ? periodValue(groups[0].value)
                : groups.map { "\($0.value.name) (\(weekdaySpan($0.first, $0.last)))" }.joined(separator: "\n")
            sections.append(DatesSection(title: "Fiscal · \(profile.name)", rows: [
                row("Fiscal year", distinct(infos.map(\.fiscalYear.name))),
                row("Quarter", distinct(infos.map { "Q\($0.quarter)" })),
                row("Period", period),
                row("Week of fiscal year", distinct(infos.map { "\($0.week.number)" })),
                row("Days of fiscal year", dayRanges(infos.map { ($0.fiscalYear.startYear, $0.dayOfYear, $0.fiscalYear.dayCount) })),
            ]))
            if groups.count > 1 {
                let parts = groups.map { group in
                    let verb = group.first == group.last ? "is" : "are"
                    return "\(range(group.first, group.last, withYear: false)) \(verb) in P\(group.value.number)"
                }
                after.append(DatesNote(lead: nil, text: "This week spans two fiscal periods: " + parts.joined(separator: ", ") + "."))
            }
        }
        if week == 53 {
            after.append(DatesNote(lead: nil, text: "\(year) has 53 ISO weeks; this is the extra one."))
        }
        return .result(DatesResult(inputLabel: "ISO week", notesBefore: [], sections: sections, notesAfter: after,
                                   needsProfile: profile == nil))
    }

    // MARK: A fiscal period

    private static func fiscalReading(_ text: String, profile: FiscalProfile?) -> DatesReading {
        func problem(_ title: String, _ detail: String, needsProfile: Bool = false) -> DatesReading {
            .problem(DatesProblem(inputLabel: "Fiscal period", title: title, detail: detail, fix: nil,
                                  needsProfile: needsProfile))
        }
        guard let profile else {
            return problem("Fiscal periods need a fiscal calendar",
                           "Add one to read inputs like FY27, Q3 FY27 or P7 FY27.", needsProfile: true)
        }

        var startYear: Int?, quarter: Int?, period: Int?
        for token in text.uppercased().split(whereSeparator: \.isWhitespace) {
            if let match = token.wholeMatch(of: /FY(\d{4})-(\d{2})/) {
                startYear = Int(match.output.1)!
            } else if let match = token.wholeMatch(of: /FY(\d{4}|\d{2})/) {
                let digits = match.output.1
                let endYear = digits.count == 2 ? 2000 + Int(digits)! : Int(digits)!
                startYear = profile.startMonth == 1 ? endYear : endYear - 1
            } else if let match = token.wholeMatch(of: /Q(\d+)/) {
                quarter = Int(match.output.1)!
            } else if let match = token.wholeMatch(of: /P(\d+)/) {
                period = Int(match.output.1)!
            } else {
                return problem("Not a fiscal period", "Try FY27, Q3 FY27 or P7 FY27.")
            }
        }
        guard let startYear, (1...9998).contains(startYear), quarter == nil || period == nil else {
            return problem("Not a fiscal period", "Try FY27, Q3 FY27 or P7 FY27.")
        }
        if let quarter, !(1...4).contains(quarter) { return problem("Quarters run Q1–Q4", "Try Q3 FY27.") }
        if let period, !(1...12).contains(period) { return problem("Periods run P1–P12", "Try P7 FY27.") }

        let year = profile.fiscalYear(startingIn: startYear)
        let isWeekBased = year.weekCount != nil
        let title: String, start: CivilDate, end: CivilDate
        var extra: [DatesRow] = []
        if let quarter {
            let periods = Array(year.periods[(quarter - 1) * 3...(quarter - 1) * 3 + 2])
            (title, start, end) = ("Q\(quarter) \(year.name)", periods[0].start, periods[2].end)
            if isWeekBased { extra.append(row("Weeks", "\(periods.compactMap(\.weeks).reduce(0, +))")) }
            extra.append(row("Periods", periods.map(\.name).joined(separator: " · ")))
        } else if let period {
            let found = year.periods[period - 1]
            (title, start, end) = ("P\(period) \(year.name)", found.start, found.end)
            if let weeks = found.weeks { extra.append(row("Weeks", "\(weeks)")) }
        } else {
            (title, start, end) = (year.name, year.start, year.end)
            if let weeks = year.weekCount { extra.append(row("Weeks", "\(weeks)")) }
        }

        let firstWeek = PeriodEngine.isoWeek(of: start).text, lastWeek = PeriodEngine.isoWeek(of: end).text
        let rows = [row("Dates", range(start, end, withYear: true)), row("Days", "\(end.days(since: start) + 1)")]
            + extra + [row("ISO weeks", firstWeek == lastWeek ? firstWeek : "\(firstWeek) – \(lastWeek)")]
        var after: [DatesNote] = []
        if let note = fiftyThreeWeekNote(year) { after.append(note) }
        return .result(DatesResult(inputLabel: "Fiscal period", notesBefore: [],
                                   sections: [DatesSection(title: "\(title) · \(profile.name)", rows: rows)],
                                   notesAfter: after, needsProfile: false))
    }

    // MARK: Shared formatting

    static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let fullMonthNames = ["January", "February", "March", "April", "May", "June", "July", "August",
                                         "September", "October", "November", "December"]

    /// `Fri 16 Oct 2026`.
    static func full(_ date: CivilDate) -> String { "\(date.shortText) \(date.year)" }

    /// `Mon 12 – Sun 18 Oct`, `Mon 26 Oct – Sun 1 Nov 2026`, `Mon 28 Dec 2026 – Sun 3 Jan 2027`.
    static func range(_ start: CivilDate, _ end: CivilDate, withYear: Bool) -> String {
        let year = withYear ? " \(end.year)" : ""
        if start == end { return start.shortText + year }
        if start.year != end.year {
            return withYear ? "\(full(start)) – \(full(end))" : "\(start.shortText) – \(end.shortText)"
        }
        if start.month == end.month { return "\(start.weekdayText) \(start.day) – \(end.shortText)\(year)" }
        return "\(start.shortText) – \(end.shortText)\(year)"
    }

    private static func row(_ label: String, _ value: String) -> DatesRow {
        DatesRow(label: label, value: value, copyText: value.replacingOccurrences(of: "\n", with: "; "))
    }

    /// `P7 · Oct` for months, `P9 · Sun 27 Sep – Sat 31 Oct` for week-based periods.
    private static func periodValue(_ period: FiscalPeriod) -> String {
        period.weeks == nil
            ? period.name.replacingOccurrences(of: " ", with: " · ")
            : "P\(period.number) · \(range(period.start, period.end, withYear: false))"
    }

    /// `Mon–Sat`, or `Sun` for one day.
    private static func weekdaySpan(_ first: CivilDate, _ last: CivilDate) -> String {
        first == last ? first.weekdayText : "\(first.weekdayText)–\(last.weekdayText)"
    }

    /// Unique values in order, `Oct · Nov`.
    private static func distinct(_ values: [String]) -> String {
        var seen: [String] = []
        for value in values where !seen.contains(value) { seen.append(value) }
        return seen.joined(separator: " · ")
    }

    /// Days grouped by year: `299–305 of 365`, or `362–365 of 365 · 1–3 of 365`.
    private static func dayRanges(_ days: [(year: Int, day: Int, total: Int)]) -> String {
        runs(of: days.map { ($0, $0.year) }).map { group in
            group.first.day == group.last.day ? "\(group.first.day) of \(group.first.total)"
                : "\(group.first.day)–\(group.last.day) of \(group.first.total)"
        }.joined(separator: " · ")
    }

    /// Consecutive items with the same key.
    private static func runs<Item, Key: Equatable>(of items: [(Item, Key)]) -> [(first: Item, last: Item, value: Key)] {
        var groups: [(first: Item, last: Item, value: Key)] = []
        for (item, key) in items {
            if let last = groups.last, last.value == key {
                groups[groups.count - 1].last = item
            } else {
                groups.append((item, item, key))
            }
        }
        return groups
    }

    private static func missingDate(year: Int, month: Int, day: Int) -> DatesProblem {
        guard (1...12).contains(month), year >= 1 else {
            return DatesProblem(inputLabel: "Date", title: "Not a date", detail: "Dates are written 2026-10-16.",
                                fix: nil, needsProfile: false)
        }
        let days = PeriodEngine.daysInMonth(year, month)
        return DatesProblem(inputLabel: "Date", title: "\(day) \(monthNames[month - 1]) \(year) doesn't exist",
                            detail: "\(fullMonthNames[month - 1]) \(year) has \(days) days.", fix: nil, needsProfile: false)
    }

    private static func fiftyThreeWeekNote(_ year: FiscalYear) -> DatesNote? {
        guard year.weekCount == 53, let last = year.periods.last?.weeks else { return nil }
        return DatesNote(lead: nil, text: "\(year.name) has 53 weeks; P12 has \(last) weeks.")
    }
}

// MARK: - Fiscal profile sheet

/// The editor's live preview (boards FiscalEditor and FiscalEditorMonths).
public struct FiscalPreview: Equatable, Sendable {
    /// `FY27 · 12 months · 365 days` or `FY2026-27 · 52 weeks`.
    public let title: String
    public let range: String
    /// `Today: Q3 · P7 Oct · week 29`.
    public let today: String
}

public enum FiscalEditorText {
    /// Week 1 under each rule, for the fiscal year containing `today`:
    /// `FY27: Mon 30 Mar – Sun 5 Apr 2026` and `FY27: Wed 1 – Sun 5 Apr (5 days)`.
    public static func week1Previews(_ profile: FiscalProfile, today: CivilDate) -> (containing: String, startsOn: String) {
        let year = profile.info(for: today).fiscalYear
        let weekStart = year.start.adding(days: -((year.start.isoWeekday - profile.weekStart + 7) % 7))
        let weekEnd = weekStart.adding(days: 6)
        let days = weekEnd.days(since: year.start) + 1
        return ("\(year.name): " + DatesText.range(weekStart, weekEnd, withYear: true),
                "\(year.name): " + DatesText.range(year.start, weekEnd, withYear: false) + " (\(days) days)")
    }

    public static func thisYear(_ profile: FiscalProfile, today: CivilDate) -> FiscalPreview {
        let info = profile.info(for: today)
        let year = info.fiscalYear
        let size = year.weekCount.map { "\($0) weeks" } ?? "12 months · \(year.dayCount) days"
        let period = info.period.weeks == nil
            ? info.period.name
            : "P\(info.period.number) (\(DatesText.range(info.period.start, info.period.end, withYear: false)))"
        return FiscalPreview(title: "\(year.name) · \(size)",
                             range: DatesText.range(year.start, year.end, withYear: true),
                             today: "Today: Q\(info.quarter) · \(period) · week \(info.week.number)")
    }

    /// The next week-based year with a 53rd week (within 12 years), for the note under the rules.
    public static func next53WeekYear(_ profile: FiscalProfile, today: CivilDate) -> DatesNote? {
        guard case .weekBased = profile.basis else { return nil }
        let first = profile.info(for: today).fiscalYear.startYear
        for startYear in first..<first + 12 {
            let year = profile.fiscalYear(startingIn: startYear)
            guard year.weekCount == 53, let weeks = year.periods.last?.weeks else { continue }
            return DatesNote(lead: "\(year.name) has 53 weeks",
                             text: "(\(DatesText.range(year.start, year.end, withYear: true))). "
                                 + "That year P12 has \(weeks) weeks instead of \(weeks - 1).")
        }
        return nil
    }

    /// `Sat nearest 31 Jan` / `Last Sat of Jan`: the week's last day in the month before the start.
    public static func yearEndLabel(_ rule: FiscalProfile.YearEndRule, startMonth: Int, weekStart: Int) -> String {
        let weekEnd = weekStart == 1 ? 7 : weekStart - 1
        let day = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][weekEnd - 1]
        let endMonth = startMonth == 1 ? 12 : startMonth - 1
        let month = DatesText.monthNames[endMonth - 1]
        switch rule {
        case .nearestMonthEnd: return "\(day) nearest \(PeriodEngine.daysInMonth(2001, endMonth)) \(month)"
        case .lastInMonth: return "Last \(day) of \(month)"
        }
    }

    /// The two naming choices for the fiscal year containing `today`: `FY27` / `FY2026-27`.
    public static func yearNames(startMonth: Int, today: CivilDate) -> (short: String, long: String) {
        let startYear = today.month >= startMonth ? today.year : today.year - 1
        let endYear = startMonth == 1 ? startYear : startYear + 1
        let short = String(format: "%02d", endYear % 100)
        return ("FY" + short, startMonth == 1 ? "FY\(startYear)" : "FY\(startYear)-" + short)
    }
}

// MARK: - Saved profiles

/// The saved fiscal profiles (decision AG): at most 3, and exactly one active while any exist.
public struct FiscalProfileList: Equatable, Sendable {
    public static let maximum = 3

    public private(set) var profiles: [FiscalProfile]
    public private(set) var activeIndex: Int?

    public init(profiles: [FiscalProfile] = [], activeIndex: Int? = nil) {
        self.profiles = Array(profiles.prefix(Self.maximum))
        if let activeIndex, self.profiles.indices.contains(activeIndex) {
            self.activeIndex = activeIndex
        } else {
            self.activeIndex = self.profiles.isEmpty ? nil : 0
        }
    }

    public var active: FiscalProfile? { activeIndex.map { profiles[$0] } }
    public var isFull: Bool { profiles.count >= Self.maximum }

    /// Adds a profile; the first one becomes active. `false` when 3 already exist.
    @discardableResult
    public mutating func add(_ profile: FiscalProfile) -> Bool {
        guard !isFull else { return false }
        profiles.append(profile)
        if activeIndex == nil { activeIndex = 0 }
        return true
    }

    public mutating func replace(at index: Int, with profile: FiscalProfile) {
        profiles[index] = profile
    }

    /// Removing the active profile makes the first remaining one active.
    public mutating func remove(at index: Int) {
        profiles.remove(at: index)
        guard let active = activeIndex else { return }
        if profiles.isEmpty {
            activeIndex = nil
        } else if active == index {
            activeIndex = 0
        } else if active > index {
            activeIndex = active - 1
        }
    }

    public mutating func activate(at index: Int) {
        activeIndex = index
    }
}

extension FiscalProfile {
    /// Starting points in "Add a fiscal calendar" (decision Y).
    public static let presets: [FiscalProfile] = [
        FiscalProfile(name: "India FY", startMonth: 4, weekStart: 1,
                      basis: .calendarMonths(week1: .containsYearStart), naming: .short),
        FiscalProfile(name: "US federal", startMonth: 10, weekStart: 7,
                      basis: .calendarMonths(week1: .containsYearStart), naming: .short),
        FiscalProfile(name: "Retail 4-4-5", startMonth: 2, weekStart: 7,
                      basis: .weekBased(pattern: .p445, yearEnd: .nearestMonthEnd), naming: .long),
    ]

    /// "Custom": calendar months from January.
    public static let custom = FiscalProfile(name: "My fiscal year", startMonth: 1, weekStart: 1,
                                             basis: .calendarMonths(week1: .containsYearStart), naming: .short)
}

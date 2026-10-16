import Foundation

public enum CronDialect: Sendable {
    /// `minute hour day-of-month month day-of-week`; Sunday is 0 or 7.
    case unix
    /// `second minute hour day-of-month month day-of-week [year]`; SUN=1 … SAT=7, and
    /// exactly one day field must be `?`.
    case quartz
}

/// A parse error shown inline under the input, with a caret at `range`.
public struct CronError: Error, Equatable, Sendable {
    /// `Field 3 · day-of-month: 32 is outside 1–31`.
    public let message: String
    /// 1-based field number, or `nil` for whole-expression errors.
    public let field: Int?
    /// The offending characters in the text that was parsed.
    public let range: Range<String.Index>?
}

/// A parsed cron expression. Evaluate with `nextRuns(after:in:count:)`.
public struct CronExpression: Sendable {
    public let dialect: CronDialect
    public let source: String

    let seconds: [Int]                      // sorted; [0] for Unix
    let minutes: [Int]
    let hours: [Int]
    let months: Set<Int>
    let years: Set<Int>?                    // Quartz only; nil = any
    let dayOfMonth: DayOfMonthRule?         // nil = any day
    let dayOfWeek: DayOfWeekRule?           // nil = any weekday; ISO Monday = 1 … Sunday = 7
    /// Unix: both day fields restricted, so a day matching either one runs.
    let daysUseOr: Bool
    /// Field texts after macro expansion, for the description.
    let rawFields: [String]

    public static func parse(_ text: String, dialect: CronDialect) throws(CronError) -> CronExpression {
        try CronParser(text: text, dialect: dialect).parse()
    }

    /// The next `count` runs after `instant`, evaluated in `zone` with the gap/overlap
    /// rule. Empty if the expression never runs (checked over a full 400-year cycle).
    public func nextRuns(after instant: Date, in zone: Zone, count: Int) -> [ScheduledRun] {
        var times: [TimeOfDay] = []
        for hour in hours {
            for minute in minutes {
                for second in seconds { times.append(TimeOfDay(hour: hour, minute: minute, second: second)) }
            }
        }
        return RunGenerator.nextRuns(after: instant, in: zone, count: count, times: times,
                                     lastYear: years?.max(), matchesDay: matches(day:))
    }

    func matches(day date: CivilDate) -> Bool {
        guard months.contains(date.month) else { return false }
        if let years, !years.contains(date.year) { return false }
        let monthDay = dayOfMonth?.matches(date), weekDay = dayOfWeek?.matches(date)
        if daysUseOr { return (monthDay ?? false) || (weekDay ?? false) }
        return (monthDay ?? true) && (weekDay ?? true)
    }
}

/// Which days of the month a field allows.
enum DayOfMonthRule: Hashable, Sendable {
    case days(Set<Int>)
    /// `L` (offset 0) or `L-3`.
    case last(offset: Int)
    /// `15W`: the weekday nearest the 15th, without leaving the month.
    case nearestWeekday(Int)
    /// `LW`: the last Monday–Friday of the month.
    case lastWeekday

    func matches(_ date: CivilDate) -> Bool {
        let daysInMonth = PeriodEngine.daysInMonth(date.year, date.month)
        switch self {
        case .days(let days):
            return days.contains(date.day)
        case .last(let offset):
            return date.day == daysInMonth - offset
        case .nearestWeekday(let day):
            guard day <= daysInMonth else { return false }
            let target = CivilDate(date.year, date.month, day)
            switch target.isoWeekday {
            case 6: return date == (day == 1 ? target.adding(days: 2) : target.adding(days: -1))
            case 7: return date == (day == daysInMonth ? target.adding(days: -2) : target.adding(days: 1))
            default: return date == target
            }
        case .lastWeekday:
            let last = CivilDate(date.year, date.month, daysInMonth)
            switch last.isoWeekday {
            case 6: return date == last.adding(days: -1)
            case 7: return date == last.adding(days: -2)
            default: return date == last
            }
        }
    }
}

/// Which weekdays a field allows, as ISO weekdays (Monday = 1 … Sunday = 7).
enum DayOfWeekRule: Hashable, Sendable {
    case days(Set<Int>)
    /// `6L`: the last Friday of the month.
    case last(Int)
    /// `6#3`: the third Friday of the month.
    case nth(Int, Int)

    func matches(_ date: CivilDate) -> Bool {
        switch self {
        case .days(let days):
            return days.contains(date.isoWeekday)
        case .last(let weekday):
            return date.isoWeekday == weekday && date.day + 7 > PeriodEngine.daysInMonth(date.year, date.month)
        case .nth(let weekday, let n):
            return date.isoWeekday == weekday && (date.day - 1) / 7 + 1 == n
        }
    }
}

// MARK: - Parser

private struct FieldSpec {
    enum Kind { case second, minute, hour, dayOfMonth, month, dayOfWeek, year }

    let kind: Kind
    let number: Int
    let bounds: ClosedRange<Int>
    let names: [String: Int]

    var name: String {
        switch kind {
        case .second: "second"
        case .minute: "minute"
        case .hour: "hour"
        case .dayOfMonth: "day-of-month"
        case .month: "month"
        case .dayOfWeek: "day-of-week"
        case .year: "year"
        }
    }
}

private struct CronParser {
    let text: String
    let dialect: CronDialect

    static let monthNames = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                             "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
    static let unixDayNames = ["SUN": 0, "MON": 1, "TUE": 2, "WED": 3, "THU": 4, "FRI": 5, "SAT": 6]
    static let quartzDayNames = ["SUN": 1, "MON": 2, "TUE": 3, "WED": 4, "THU": 5, "FRI": 6, "SAT": 7]
    static let macros = ["@yearly": "0 0 1 1 *", "@annually": "0 0 1 1 *", "@monthly": "0 0 1 * *",
                         "@weekly": "0 0 * * 0", "@daily": "0 0 * * *", "@midnight": "0 0 * * *",
                         "@hourly": "0 * * * *"]

    func parse() throws(CronError) -> CronExpression {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw CronError(message: "Type a cron expression", field: nil, range: nil) }

        if trimmed.hasPrefix("@") {
            guard dialect == .unix, let expansion = Self.macros[trimmed.lowercased()] else {
                throw CronError(message: "\(trimmed) is not a schedule macro", field: nil, range: nil)
            }
            let expanded = try CronParser(text: expansion, dialect: .unix).parse()
            return CronExpression(dialect: .unix, source: text, seconds: expanded.seconds, minutes: expanded.minutes,
                                  hours: expanded.hours, months: expanded.months, years: nil,
                                  dayOfMonth: expanded.dayOfMonth, dayOfWeek: expanded.dayOfWeek,
                                  daysUseOr: expanded.daysUseOr, rawFields: expanded.rawFields)
        }

        let fields = text.split(whereSeparator: \.isWhitespace)
        switch dialect {
        case .unix:
            guard fields.count == 5 else {
                let hint = fields.count == 6 ? ". Seconds need Quartz" : ""
                throw CronError(message: "Unix cron needs 5 fields; found \(fields.count)\(hint)", field: nil, range: nil)
            }
            return try parseUnix(fields)
        case .quartz:
            guard fields.count == 6 || fields.count == 7 else {
                throw CronError(message: "Quartz needs 6 or 7 fields; found \(fields.count)", field: nil, range: nil)
            }
            return try parseQuartz(fields)
        }
    }

    private func parseUnix(_ fields: [Substring]) throws(CronError) -> CronExpression {
        let minute = FieldSpec(kind: .minute, number: 1, bounds: 0...59, names: [:])
        let hour = FieldSpec(kind: .hour, number: 2, bounds: 0...23, names: [:])
        let monthDay = FieldSpec(kind: .dayOfMonth, number: 3, bounds: 1...31, names: [:])
        let month = FieldSpec(kind: .month, number: 4, bounds: 1...12, names: Self.monthNames)
        let weekDay = FieldSpec(kind: .dayOfWeek, number: 5, bounds: 0...7, names: Self.unixDayNames)

        // Vixie cron: a day field starting with `*` is "unrestricted" for the OR rule,
        // even `*/2`, which still filters the days.
        let monthDayIsStar = fields[2].hasPrefix("*"), weekDayIsStar = fields[4].hasPrefix("*")
        let monthDays = try numbers(fields[2], monthDay)
        let weekDays = Set(try numbers(fields[4], weekDay).map { $0 == 0 ? 7 : $0 })

        return CronExpression(
            dialect: .unix, source: text, seconds: [0],
            minutes: try numbers(fields[0], minute).sorted(), hours: try numbers(fields[1], hour).sorted(),
            months: try numbers(fields[3], month), years: nil,
            dayOfMonth: fields[2] == "*" ? nil : .days(monthDays),
            dayOfWeek: fields[4] == "*" ? nil : .days(weekDays),
            daysUseOr: !monthDayIsStar && !weekDayIsStar,
            rawFields: fields.map(String.init))
    }

    private func parseQuartz(_ fields: [Substring]) throws(CronError) -> CronExpression {
        let second = FieldSpec(kind: .second, number: 1, bounds: 0...59, names: [:])
        let minute = FieldSpec(kind: .minute, number: 2, bounds: 0...59, names: [:])
        let hour = FieldSpec(kind: .hour, number: 3, bounds: 0...23, names: [:])
        let monthDay = FieldSpec(kind: .dayOfMonth, number: 4, bounds: 1...31, names: [:])
        let month = FieldSpec(kind: .month, number: 5, bounds: 1...12, names: Self.monthNames)
        let weekDay = FieldSpec(kind: .dayOfWeek, number: 6, bounds: 1...7, names: Self.quartzDayNames)
        let year = FieldSpec(kind: .year, number: 7, bounds: 1970...2099, names: [:])

        let questionMarks = [fields[3], fields[5]].filter { $0 == "?" }.count
        guard questionMarks == 1 else {
            throw CronError(message: "Quartz needs ? in exactly one of day-of-month and day-of-week",
                            field: questionMarks == 0 ? 4 : nil,
                            range: questionMarks == 0 ? fields[3].startIndex..<fields[3].endIndex : nil)
        }

        return CronExpression(
            dialect: .quartz, source: text,
            seconds: try numbers(fields[0], second).sorted(), minutes: try numbers(fields[1], minute).sorted(),
            hours: try numbers(fields[2], hour).sorted(), months: try numbers(fields[4], month),
            years: fields.count == 7 && fields[6] != "*" ? try numbers(fields[6], year) : nil,
            dayOfMonth: try quartzDayOfMonth(fields[3], monthDay),
            dayOfWeek: try quartzDayOfWeek(fields[5], weekDay),
            daysUseOr: false,
            rawFields: fields.map(String.init))
    }

    private func quartzDayOfMonth(_ field: Substring, _ spec: FieldSpec) throws(CronError) -> DayOfMonthRule? {
        let upper = field.uppercased()
        if field == "?" || field == "*" { return nil }
        if upper == "L" { return .last(offset: 0) }
        if upper == "LW" { return .lastWeekday }
        if upper.hasPrefix("L-") {
            let token = field.dropFirst(2)
            guard let offset = Int(token), (1...30).contains(offset) else {
                throw error(spec, "\(field) is outside L-1–L-30", at: field)
            }
            return .last(offset: offset)
        }
        if upper.hasSuffix("W") {
            let token = field.dropLast()
            return .nearestWeekday(try value(token, spec))
        }
        return .days(try numbers(field, spec))
    }

    private func quartzDayOfWeek(_ field: Substring, _ spec: FieldSpec) throws(CronError) -> DayOfWeekRule? {
        let toISO = { (quartz: Int) in quartz == 1 ? 7 : quartz - 1 }
        if field == "?" || field == "*" { return nil }
        if field.uppercased() == "L" { return .days([6]) }                // L alone = SAT
        if let hash = field.firstIndex(of: "#") {
            let weekday = try value(field[..<hash], spec)
            let nToken = field[field.index(after: hash)...]
            guard let n = Int(nToken), (1...5).contains(n) else {
                throw error(spec, "#\(nToken) is outside #1–#5", at: field)
            }
            return .nth(toISO(weekday), n)
        }
        if field.count > 1, field.uppercased().hasSuffix("L") {
            return .last(toISO(try value(field.dropLast(), spec)))
        }
        return .days(Set(try numbers(field, spec).map(toISO)))
    }

    /// Lists, ranges and steps: `1,15`, `9-17`, `*/15`, `5/20`, `MON-FRI`.
    private func numbers(_ field: Substring, _ spec: FieldSpec) throws(CronError) -> Set<Int> {
        if field.contains("?") {
            let mark = field.firstIndex(of: "?")!
            let message = dialect == .unix ? "? is Quartz only" : "? is only allowed in day-of-month or day-of-week"
            throw error(spec, message, at: field[mark...mark])
        }
        var result = Set<Int>()
        for item in field.split(separator: ",", omittingEmptySubsequences: false) {
            guard !item.isEmpty else { throw error(spec, "empty list item", at: field) }
            let parts = item.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            let base = parts[0]
            var step = 1
            if parts.count == 2 {
                guard let parsed = Int(parts[1]) else { throw error(spec, "\(parts[1]) is not a step", at: parts[1]) }
                guard parsed >= 1 else { throw error(spec, "step must be at least 1", at: parts[1]) }
                step = parsed
            }

            let low: Int, high: Int
            if base == "*" {
                (low, high) = (spec.bounds.lowerBound, spec.bounds.upperBound)
            } else if let dash = base.firstIndex(of: "-"), dash != base.startIndex {
                low = try value(base[..<dash], spec)
                high = try value(base[base.index(after: dash)...], spec)
                guard low <= high else { throw error(spec, "range \(base) runs backwards", at: base) }
            } else {
                low = try value(base, spec)
                high = parts.count == 2 ? spec.bounds.upperBound : low
            }
            for number in stride(from: low, through: high, by: step) { result.insert(number) }
        }
        return result
    }

    /// One number or name, checked against the field's bounds.
    private func value(_ token: Substring, _ spec: FieldSpec) throws(CronError) -> Int {
        if !token.isEmpty, token.allSatisfy({ ("0"..."9").contains($0) }), let number = Int(token) {
            guard spec.bounds.contains(number) else {
                throw error(spec, "\(number) is outside \(spec.bounds.lowerBound)–\(spec.bounds.upperBound)", at: token)
            }
            return number
        }
        if let number = spec.names[token.uppercased()] { return number }
        if dialect == .unix, let special = token.uppercased().first(where: { "LW#".contains($0) }) {
            throw error(spec, "\(special) is Quartz only", at: token)
        }
        switch spec.kind {
        case .dayOfWeek: throw error(spec, "\(token) is not a day name or number", at: token)
        case .month: throw error(spec, "\(token) is not a month name or number", at: token)
        default: throw error(spec, "\(token) is not a number", at: token)
        }
    }

    private func error(_ spec: FieldSpec, _ detail: String, at token: Substring) -> CronError {
        CronError(message: "Field \(spec.number) · \(spec.name): \(detail)", field: spec.number,
                  range: token.startIndex..<token.endIndex)
    }
}

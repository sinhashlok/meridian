import Foundation

/// A calendar date with no time and no zone (`2026-10-25`). Day arithmetic is whole
/// days on the proleptic Gregorian calendar, so a 23- or 25-hour day is still one day.
public struct CivilDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// The date must exist (`CivilDate(2026, 2, 30)` stops the program).
    /// Use `init?(iso:)` for user input.
    public init(_ year: Int, _ month: Int, _ day: Int) {
        precondition(Self.isValid(year, month, day), "invalid date \(year)-\(month)-\(day)")
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`; `nil` if malformed or the date doesn't exist.
    public init?(iso: String) {
        guard let match = iso.trimmingCharacters(in: .whitespaces).wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/),
              let year = Int(match.output.1), let month = Int(match.output.2), let day = Int(match.output.3),
              Self.isValid(year, month, day)
        else { return nil }
        self.init(year, month, day)
    }

    /// Days since 1970-01-01 (negative before).
    var daysSinceEpoch: Int {
        Int(GregorianDays.days(year: Int64(year), month: Int64(month), day: Int64(day)))
    }

    init(daysSinceEpoch days: Int) {
        let (year, month, day) = GregorianDays.date(fromDays: Int64(days))
        self.init(Int(year), Int(month), Int(day))
    }

    public func adding(days: Int) -> CivilDate {
        CivilDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// Whole days from `other` to this date (positive if this date is later).
    public func days(since other: CivilDate) -> Int {
        daysSinceEpoch - other.daysSinceEpoch
    }

    /// ISO weekday: Monday = 1 … Sunday = 7. (Foundation's `weekday` is Sunday = 1.)
    public var isoWeekday: Int {
        // 1970-01-01 was a Thursday (4).
        Int(Int64(daysSinceEpoch + 3) - floorDiv(Int64(daysSinceEpoch + 3), 7) * 7) + 1
    }

    /// `Mon 26 Oct`, for notes and labels.
    public var shortText: String {
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return "\(weekdays[isoWeekday - 1]) \(day) \(months[month - 1])"
    }

    public static func < (a: CivilDate, b: CivilDate) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    static func isValid(_ year: Int, _ month: Int, _ day: Int) -> Bool {
        (1...9999).contains(year) && (1...12).contains(month)
            && (1...Int(GregorianDays.daysInMonth(year: Int64(year), month: Int64(month)))).contains(day)
    }
}

/// A wall-clock time on a date, with no zone (`2026-11-01 01:30`).
public struct LocalDateTime: Hashable, Sendable {
    public let date: CivilDate
    public let hour: Int
    public let minute: Int

    public init(date: CivilDate, hour: Int, minute: Int) {
        precondition((0...23).contains(hour) && (0...59).contains(minute), "invalid time \(hour):\(minute)")
        self.date = date
        self.hour = hour
        self.minute = minute
    }
}

/// `07` for 7: zero-padded to two digits, for clock text.
func twoDigits(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }

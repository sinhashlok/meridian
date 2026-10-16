import Foundation

/// Units an epoch number can be written in.
public enum EpochUnit: String, CaseIterable, Sendable {
    case seconds, milliseconds, microseconds, nanoseconds

    /// How many of this unit make one second.
    var perSecond: Int64 {
        switch self {
        case .seconds: 1
        case .milliseconds: 1_000
        case .microseconds: 1_000_000
        case .nanoseconds: 1_000_000_000
        }
    }

    /// Fraction digits this unit can carry when written as ISO 8601.
    var fractionDigits: Int {
        switch self {
        case .seconds: 0
        case .milliseconds: 3
        case .microseconds: 6
        case .nanoseconds: 9
        }
    }
}

/// An instant held as integers, so nanosecond values never pass through `Double`.
public struct EpochValue: Hashable, Sendable {
    /// Whole seconds since 1970-01-01T00:00:00Z, rounded down (so -1.5 s is -2 s + 0.5 s).
    public let seconds: Int64
    /// Nanoseconds past `seconds`, always 0...999_999_999.
    public let nanoseconds: Int32

    public init(seconds: Int64, nanoseconds: Int32) {
        precondition((0..<1_000_000_000).contains(nanoseconds), "nanoseconds must be 0...999_999_999")
        self.seconds = seconds
        self.nanoseconds = nanoseconds
    }

    /// `count` of `unit` since the epoch, e.g. 1_792_060_800_000 milliseconds.
    public init(count: Int64, unit: EpochUnit) {
        let perSecond = unit.perSecond
        let seconds = floorDiv(count, perSecond)
        let remainder = count - seconds * perSecond                      // 0..<perSecond
        self.init(seconds: seconds, nanoseconds: Int32(remainder * (1_000_000_000 / perSecond)))
    }

    /// This instant as a count of `unit`, rounded down. `nil` if it doesn't fit in `Int64`.
    public func count(in unit: EpochUnit) -> Int64? {
        let (whole, overflow) = seconds.multipliedReportingOverflow(by: unit.perSecond)
        guard !overflow else { return nil }
        let part = Int64(nanoseconds) / (1_000_000_000 / unit.perSecond)
        let (total, overflow2) = whole.addingReportingOverflow(part)
        return overflow2 ? nil : total
    }

    /// For the UI. Lossy below about a microsecond: use the integer fields for display.
    public var date: Date {
        Date(timeIntervalSince1970: Double(seconds) + Double(nanoseconds) / 1_000_000_000)
    }

    /// `2026-10-15T10:40:00Z`, or with `precision`'s fraction digits when the fraction
    /// isn't zero (`1970-01-21T17:47:40.800Z`). Only valid within `isInISORange`.
    public func utcISOString(precision: EpochUnit = .nanoseconds) -> String {
        let days = floorDiv(seconds, 86_400)
        let secondOfDay = seconds - days * 86_400
        let (year, month, day) = GregorianDays.date(fromDays: days)
        var text = pad(year, 4) + "-" + pad(month, 2) + "-" + pad(day, 2)
            + "T" + pad(secondOfDay / 3600, 2) + ":" + pad(secondOfDay / 60 % 60, 2) + ":" + pad(secondOfDay % 60, 2)

        let digits = precision.fractionDigits
        if digits > 0 {
            let fraction = Int64(nanoseconds) / pow10(9 - digits)
            if fraction != 0 { text += "." + pad(fraction, digits) }
        }
        return text + "Z"
    }

    /// ISO 8601 four-digit years: 0001-01-01T00:00:00Z ... 9999-12-31T23:59:59.999999999Z.
    public var isInISORange: Bool {
        (Self.earliestISOSecond...Self.latestISOSecond).contains(seconds)
    }

    static let earliestISOSecond: Int64 = -62_135_596_800    // 0001-01-01T00:00:00Z
    static let latestISOSecond: Int64 = 253_402_300_799      // 9999-12-31T23:59:59Z
}

/// What `EpochParser.parse` understood.
public struct EpochParseResult: Equatable, Sendable {
    public let value: EpochValue
    /// The unit used: detected from the digit count, or the caller's override.
    public let unit: EpochUnit
    /// True when the digit count fits two units; the UI shows the assumption and an override.
    public let isAmbiguous: Bool
    /// The other unit the number could be in (empty unless ambiguous).
    public let alternatives: [EpochUnit]

    public var utcISOString: String { value.utcISOString(precision: unit) }
}

public enum EpochError: Error, Equatable, Sendable {
    case empty
    case notAnInteger
    /// More digits than `Int64` holds.
    case tooLarge
    /// Outside ISO 8601 years 0001–9999.
    case outOfRange
    case invalidISO8601
    /// A date-time with no `Z` or offset. M4 resolves it in the Interpret-as zone.
    case missingZone
}

public enum EpochParser {
    /// Parses an integer epoch. Spaces, `_` and `,` are ignored; a leading `-` is allowed.
    /// Without `unit`, the unit comes from the number of significant digits:
    ///
    /// | Digits | Unit |
    /// |---|---|
    /// | 1–10 | seconds |
    /// | 11–12 | ambiguous, default milliseconds (seconds would be year 2286+) |
    /// | 13 | milliseconds |
    /// | 14–15 | ambiguous, default microseconds |
    /// | 16 | microseconds |
    /// | 17–18 | ambiguous, default nanoseconds |
    /// | 19 | nanoseconds |
    public static func parse(_ input: String, as unit: EpochUnit? = nil) throws(EpochError) -> EpochParseResult {
        let cleaned = input.filter { !$0.isWhitespace && $0 != "_" && $0 != "," }
        guard !cleaned.isEmpty else { throw .empty }

        let digits = cleaned.hasPrefix("-") ? cleaned.dropFirst() : Substring(cleaned)
        guard !digits.isEmpty, digits.allSatisfy({ ("0"..."9").contains($0) }) else { throw .notAnInteger }
        guard let count = Int64(cleaned) else { throw .tooLarge }

        let significantDigits = max(digits.drop(while: { $0 == "0" }).count, 1)
        let (chosen, alternatives) = unit.map { ($0, []) } ?? detectUnit(significantDigits: significantDigits)

        let value = EpochValue(count: count, unit: chosen)
        guard value.isInISORange else { throw .outOfRange }
        return EpochParseResult(value: value, unit: chosen, isAmbiguous: !alternatives.isEmpty, alternatives: alternatives)
    }

    /// Parses `YYYY-MM-DDTHH:MM[:SS[.fffffffff]]` followed by `Z` or `±HH:MM` (`T` may be
    /// a space). Up to 9 fraction digits, kept exactly.
    public static func parseISO8601(_ input: String) throws(EpochError) -> EpochValue {
        let pattern = /(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?(Z|z|[+-]\d{2}:?\d{2})?/
        guard let match = input.trimmingCharacters(in: .whitespaces).wholeMatch(of: pattern) else {
            throw .invalidISO8601
        }
        let (_, y, mo, d, h, mi, s, fraction, zone) = match.output
        let year = Int64(y)!, month = Int64(mo)!, day = Int64(d)!
        let hour = Int64(h)!, minute = Int64(mi)!, second = s.map { Int64($0)! } ?? 0

        guard (1...12).contains(month),
              (1...GregorianDays.daysInMonth(year: year, month: month)).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second)
        else { throw .invalidISO8601 }

        guard let zone else { throw .missingZone }
        let offsetSeconds = try offset(String(zone))

        var nanoseconds: Int64 = 0
        if let fraction {
            nanoseconds = Int64(fraction)! * pow10(9 - fraction.count)
        }

        let days = GregorianDays.days(year: year, month: month, day: day)
        let seconds = days * 86_400 + hour * 3600 + minute * 60 + second - offsetSeconds
        let value = EpochValue(seconds: seconds, nanoseconds: Int32(nanoseconds))
        guard year >= 1, value.isInISORange else { throw .outOfRange }
        return value
    }

    // MARK: Private

    private static func detectUnit(significantDigits: Int) -> (EpochUnit, [EpochUnit]) {
        switch significantDigits {
        case ...10: (.seconds, [])
        case 11...12: (.milliseconds, [.seconds])
        case 13: (.milliseconds, [])
        case 14...15: (.microseconds, [.milliseconds])
        case 16: (.microseconds, [])
        case 17...18: (.nanoseconds, [.microseconds])
        default: (.nanoseconds, [])      // 19; more digits never fit Int64
        }
    }

    /// Seconds east of UTC for `Z`, `+05:30` or `-0700`.
    private static func offset(_ zone: String) throws(EpochError) -> Int64 {
        if zone == "Z" || zone == "z" { return 0 }
        let sign: Int64 = zone.hasPrefix("-") ? -1 : 1
        let numbers = zone.dropFirst().filter { $0 != ":" }
        let hours = Int64(numbers.prefix(2))!, minutes = Int64(numbers.suffix(2))!
        guard hours <= 23, minutes <= 59 else { throw .invalidISO8601 }
        return sign * (hours * 3600 + minutes * 60)
    }
}

private func pad(_ value: Int64, _ width: Int) -> String {
    let digits = String(value)
    return String(repeating: "0", count: max(0, width - digits.count)) + digits
}

private func pow10(_ exponent: Int) -> Int64 {
    (0..<exponent).reduce(1) { result, _ in result * 10 }
}

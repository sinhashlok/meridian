import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § EpochParser, plus decision C (docs/decisions.md):
/// digit-count bands and their ambiguous defaults.
@Suite("EpochParser")
struct EpochParserTests {

    // MARK: Fixture rows

    @Test("Detects the unit and converts to UTC", arguments: [
        ("0", EpochUnit.seconds, "1970-01-01T00:00:00Z"),
        ("1000000000", .seconds, "2001-09-09T01:46:40Z"),
        ("1792060800", .seconds, "2026-10-15T10:40:00Z"),           // 16:10 IST
        ("1792060800000", .milliseconds, "2026-10-15T10:40:00Z"),   // 13 digits
        ("1792888200", .seconds, "2026-10-25T00:30:00Z"),
        ("-86400", .seconds, "1969-12-31T00:00:00Z"),               // negative is valid
    ])
    func fixtureRows(input: String, unit: EpochUnit, utc: String) throws {
        let result = try EpochParser.parse(input)
        #expect(result.unit == unit)
        #expect(result.isAmbiguous == false)
        #expect(result.utcISOString == utc)
    }

    @Test("Override reads a 10-digit value as milliseconds")
    func overrideAsMilliseconds() throws {
        let result = try EpochParser.parse("1792060800", as: .milliseconds)
        #expect(result.unit == .milliseconds)
        #expect(result.isAmbiguous == false)
        #expect(result.utcISOString == "1970-01-21T17:47:40.800Z")
    }

    @Test("19-digit nanoseconds round-trip exactly through Int64")
    func nanosecondsRoundTrip() throws {
        let input = "1792060800123456789"
        let result = try EpochParser.parse(input)
        #expect(result.unit == .nanoseconds)
        #expect(result.value.seconds == 1_792_060_800)
        #expect(result.value.nanoseconds == 123_456_789)
        #expect(result.utcISOString == "2026-10-15T10:40:00.123456789Z")
        #expect(result.value.count(in: .nanoseconds) == 1_792_060_800_123_456_789)

        // Back through the ISO parser: the same Int64, not a Double approximation.
        let reparsed = try EpochParser.parseISO8601(result.utcISOString)
        #expect(reparsed == result.value)
        #expect(reparsed.count(in: .nanoseconds) == Int64(input))
    }

    @Test("Reverse: ISO 8601 to epoch")
    func reverse() throws {
        #expect(try EpochParser.parseISO8601("2026-10-15T10:40:00Z").seconds == 1_792_060_800)
        // Same instant written with the IST offset (fixture: 16:10 IST).
        #expect(try EpochParser.parseISO8601("2026-10-15T16:10:00+05:30").seconds == 1_792_060_800)
    }

    // MARK: Ambiguous digit counts (fixture: 11–12 digits; decision C for the rest)

    @Test("Ambiguous digit counts default to the larger unit and offer the smaller", arguments: [
        ("17920608000", EpochUnit.milliseconds, EpochUnit.seconds),            // 11 digits
        ("179206080000", .milliseconds, .seconds),                             // 12
        ("17920608000000", .microseconds, .milliseconds),                      // 14
        ("179206080000000", .microseconds, .milliseconds),                     // 15
        ("17920608000000000", .nanoseconds, .microseconds),                    // 17
        ("179206080000000000", .nanoseconds, .microseconds),                   // 18
    ])
    func ambiguous(input: String, defaultUnit: EpochUnit, alternative: EpochUnit) throws {
        let result = try EpochParser.parse(input)
        #expect(result.isAmbiguous)
        #expect(result.unit == defaultUnit)
        #expect(result.alternatives == [alternative])
    }

    @Test("Unambiguous digit counts", arguments: [
        (10, EpochUnit.seconds), (13, .milliseconds), (16, .microseconds), (19, .nanoseconds),
    ])
    func unambiguousBands(digits: Int, unit: EpochUnit) throws {
        let result = try EpochParser.parse("1" + String(repeating: "0", count: digits - 1))
        #expect(result.unit == unit)
        #expect(result.isAmbiguous == false)
        #expect(result.alternatives.isEmpty)
    }

    // MARK: Integer edge cases

    @Test("Negative sub-second values floor, not truncate")
    func negativeMilliseconds() throws {
        let result = try EpochParser.parse("-1500", as: .milliseconds)
        #expect(result.value.seconds == -2)
        #expect(result.value.nanoseconds == 500_000_000)
        #expect(result.utcISOString == "1969-12-31T23:59:58.500Z")
    }

    @Test("Digit separators are ignored")
    func separators() throws {
        #expect(try EpochParser.parse("1_792_060_800").value.seconds == 1_792_060_800)
        #expect(try EpochParser.parse(" 1,792,060,800 ").value.seconds == 1_792_060_800)
    }

    @Test("Invalid input throws", arguments: [
        ("", EpochError.empty),
        ("   ", .empty),
        ("12.5", .notAnInteger),
        ("abc", .notAnInteger),
        ("--5", .notAnInteger),
        ("99999999999999999999", .tooLarge),       // 20 digits: beyond Int64
    ])
    func invalid(input: String, error: EpochError) {
        #expect(throws: error) { try EpochParser.parse(input) }
    }

    @Test("Int64.max as nanoseconds is a valid instant (2262)")
    func int64Max() throws {
        let result = try EpochParser.parse("9223372036854775807")
        #expect(result.utcISOString == "2262-04-11T23:47:16.854775807Z")
    }

    @Test("Values outside years 0001–9999 are out of range")
    func outOfRange() throws {
        // 253402300800 s = 10000-01-01T00:00:00Z, one second past the ISO 8601 4-digit range.
        #expect(throws: EpochError.outOfRange) { try EpochParser.parse("253402300800", as: .seconds) }
        #expect(throws: EpochError.outOfRange) { try EpochParser.parse("-62135596801", as: .seconds) }
        #expect(try EpochParser.parse("253402300799", as: .seconds).utcISOString == "9999-12-31T23:59:59Z")
        #expect(try EpochParser.parse("-62135596800", as: .seconds).utcISOString == "0001-01-01T00:00:00Z")
    }

    @Test("Integer calendar round-trips every day 0001–9999 and agrees with Foundation after 1582")
    func gregorianDays() {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = .gmt
        let first = GregorianDays.days(year: 1, month: 1, day: 1)
        let last = GregorianDays.days(year: 9999, month: 12, day: 31)
        var mismatches = 0
        for days in first...last {
            let (y, m, d) = GregorianDays.date(fromDays: days)
            if GregorianDays.days(year: y, month: m, day: d) != days { mismatches += 1 }
            // Foundation's Gregorian calendar is Julian before 15 Oct 1582, so compare after.
            if y >= 1583, days % 97 == 0 {
                let parts = gregorian.dateComponents([.year, .month, .day],
                                                     from: Date(timeIntervalSince1970: Double(days) * 86_400))
                if (parts.year, parts.month, parts.day) != (Int(y), Int(m), Int(d)) { mismatches += 1 }
            }
        }
        #expect(mismatches == 0)
        #expect(GregorianDays.days(year: 1970, month: 1, day: 1) == 0)
    }

    @Test("ISO input without a zone needs one (M4: Interpret-as chip)")
    func missingZone() {
        #expect(throws: EpochError.missingZone) { try EpochParser.parseISO8601("2026-10-15T10:40:00") }
    }

    @Test("Malformed ISO input throws", arguments: [
        "2026-13-01T00:00:00Z", "2026-02-30T00:00:00Z", "2026-10-15T24:00:00Z",
        "2026-10-15T10:40:00.1234567890Z", "15/10/2026 10:40", "",
    ])
    func malformedISO(input: String) {
        #expect(throws: EpochError.invalidISO8601) { try EpochParser.parseISO8601(input) }
    }
}

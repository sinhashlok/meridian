import Foundation
import Testing
@testable import MeridianCore

/// Tools › Epoch wording (boards Epoch, EpochInvalid, EpochRange, EpochAmbiguous,
/// EpochZoneless; spec §4.6; decisions W, AD, AE). Expected values checked with Python.
@Suite("Epoch text")
struct EpochTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let ny = Zone("America/New_York")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }
    static let boardNow = utc("2026-10-15T15:32:07Z")

    // MARK: Input kind

    @Test("Input kind: epoch digits or a date-time", arguments: [
        ("", EpochInputKind.empty), ("   ", .empty),
        ("1792060800000", .epoch), ("-86400", .epoch), ("1792O60800000", .epoch), ("1 792 060 800", .epoch),
        ("2026-10-15T10:40:00Z", .dateTime), ("2026-10-25 01:30", .dateTime),
    ])
    func kind(input: String, kind: EpochInputKind) {
        #expect(EpochText.kind(of: input) == kind)
    }

    // MARK: Rows

    @Test("Result rows for the board's 13-digit timestamp")
    func rows() throws {
        let parsed = try EpochParser.parse("1792060800000")
        let rows = EpochText.rows(parsed.value, precision: parsed.unit, local: Self.ist, isoZone: .utc, now: Self.boardNow)
        #expect(rows == [
            EpochRow(label: "UTC", value: "Thu 15 Oct 2026 10:40:00", copyText: "Thu 15 Oct 2026 10:40:00 UTC"),
            EpochRow(label: "Local · IST (UTC+5:30)", value: "Thu 15 Oct 2026 16:10:00",
                     copyText: "Thu 15 Oct 2026 16:10:00 IST (UTC+5:30)"),
            EpochRow(label: "ISO 8601", value: "2026-10-15T10:40:00Z", copyText: "2026-10-15T10:40:00Z"),
            EpochRow(label: "Relative", value: "4 h 52 min ago", copyText: "4 h 52 min ago"),
            EpochRow(label: "Unix seconds", value: "1792060800", copyText: "1792060800"),
        ])
    }

    @Test("Date-times are formatted with integer maths, before 1970 too")
    func dateTimes() {
        #expect(EpochText.dateTime(EpochValue(seconds: -86_400, nanoseconds: 0), in: .utc) == "Wed 31 Dec 1969 00:00:00")
        #expect(EpochText.dateTime(EpochValue(seconds: 1_792_888_200, nanoseconds: 0), in: Self.ist)
                == "Sun 25 Oct 2026 06:00:00")
        #expect(EpochText.shortDate(EpochValue(count: 17_920_608_000, unit: .milliseconds)) == "27 Jul 1970")
        #expect(EpochText.shortDate(EpochValue(count: 17_920_608_000, unit: .seconds)) == "18 Nov 2537")
    }

    @Test("ISO 8601 in a zone carries the zone's offset; UTC is Z")
    func isoInZone() {
        let value = EpochValue(seconds: 1_792_888_200, nanoseconds: 0)
        #expect(EpochText.isoString(value, in: Self.london, precision: .seconds) == "2026-10-25T01:30:00+01:00")
        #expect(EpochText.isoString(EpochValue(seconds: 1_792_891_800, nanoseconds: 0), in: Self.london,
                                    precision: .seconds) == "2026-10-25T01:30:00+00:00")
        #expect(EpochText.isoString(value, in: Self.ist, precision: .milliseconds) == "2026-10-25T06:00:00+05:30")
        #expect(EpochText.isoString(value, in: .utc, precision: .seconds) == "2026-10-25T00:30:00Z")
    }

    @Test("Relative time (decision AE)", arguments: [
        ("2026-10-15T10:40:00Z", "4 h 52 min ago"),
        ("2026-10-15T15:32:00Z", "just now"),
        ("2026-10-15T15:30:37Z", "1 min ago"),
        ("2026-10-15T12:32:07Z", "3 h ago"),
        ("2026-08-31T15:32:07Z", "45 days ago"),
        ("2026-08-06T15:32:07Z", "2 months ago"),
        ("2025-01-01T00:00:00Z", "21 months ago"),
        ("2024-06-15T15:32:07Z", "2 years ago"),
        ("1970-07-27T09:56:48Z", "56 years ago"),
        ("2026-10-24T03:00:00Z", "in 8 days"),
        ("2026-10-15T15:45:07Z", "in 13 min"),
    ])
    func relative(instant: String, text: String) throws {
        let value = try EpochParser.parseISO8601(instant)
        #expect(EpochText.relative(value, now: Self.boardNow) == text)
    }

    // MARK: Unit chip and ambiguity

    @Test("Unit chip: significant digits and the unit read", arguments: [
        ("1792060800000", nil as EpochUnit?, "13 digits", "milliseconds"),
        ("1792060800", EpochUnit.milliseconds, "10 digits", "milliseconds"),
        ("17920608000", nil, "11 digits", "milliseconds"),
        ("17920608000000000000", nil, "20 digits", "no unit fits"),
        ("-86400", nil, "5 digits", "seconds"),
    ])
    func unitChip(input: String, unit: EpochUnit?, digits: String, read: String) {
        let chip = EpochText.unitChip(for: input, unit: unit)
        #expect(chip.digits == digits)
        #expect(chip.unit == read)
    }

    @Test("Ambiguous 11 digits: why milliseconds, and both readings")
    func ambiguity() throws {
        let parsed = try EpochParser.parse("17920608000")
        #expect(EpochText.ambiguity(parsed, input: "17920608000", now: Self.boardNow) == EpochNote(
            title: "11 digits is not a standard length",
            detail: "Showing milliseconds because it is closer to today. Neither reading is recent, so a digit may be missing."))
        let chosen = try EpochParser.parse("17920608000", as: .seconds)
        #expect(EpochText.ambiguity(chosen, input: "17920608000", now: Self.boardNow)?.detail
                == "Showing seconds, as you chose. Neither reading is recent, so a digit may be missing.")
        #expect(EpochText.candidateUnits(for: "17920608000") == [.seconds, .milliseconds])
        #expect(EpochText.candidateUnits(for: "1792060800000").isEmpty)
        #expect(EpochText.readings(of: "17920608000", units: [.seconds, .milliseconds]).map(\.dateText)
                == ["18 Nov 2537", "27 Jul 1970"])
        #expect(EpochText.ambiguity(try EpochParser.parse("1792060800000"), input: "1792060800000", now: Self.boardNow) == nil)
    }

    // MARK: Problems

    @Test("A letter O in place of zero: position and a fix (decision AD)")
    func letterO() throws {
        let problem = try #require(EpochText.problem(in: "1792O60800000"))
        #expect(problem.title == "Contains a letter: character 5 is “O”, not zero")
        #expect(problem.detail == "Epochs are digits only, with an optional leading minus.")
        #expect(problem.characterIndex == 5)
        #expect(problem.fix == EpochFix(label: "0", input: "1792060800000"))
    }

    @Test("Other bad characters: no fix offered", arguments: [
        ("17x2", "Contains a letter: character 3 is “x”", 3, false),
        ("1l92", "Contains a letter: character 2 is “l”, not one", 2, true),
        ("12.5", "Not a whole number: character 3 is “.”", 3, false),
    ])
    func otherCharacters(input: String, title: String, index: Int, hasFix: Bool) throws {
        let problem = try #require(EpochText.problem(in: input))
        #expect(problem.title == title)
        #expect(problem.characterIndex == index)
        #expect((problem.fix != nil) == hasFix)
    }

    @Test("20 digits: longer than any epoch, with what each length would read (decision W)")
    func tooLong() throws {
        let problem = try #require(EpochText.problem(in: "17920608000000000000"))
        #expect(problem.title == "Out of range: 20 digits is longer than any epoch")
        #expect(problem.detail == "Nanoseconds is the longest unit (19 digits) and stops at 2262-04-11 23:47:16 UTC. "
                + "Were two values pasted together?")
        #expect(problem.readings == [
            EpochReading(digits: 10, unit: .seconds, prefix: "1792060800", dateText: "Thu 15 Oct 2026"),
            EpochReading(digits: 13, unit: .milliseconds, prefix: "1792060800000", dateText: "Thu 15 Oct 2026"),
            EpochReading(digits: 16, unit: .microseconds, prefix: "1792060800000000", dateText: "Thu 15 Oct 2026"),
            EpochReading(digits: 19, unit: .nanoseconds, prefix: "1792060800000000000", dateText: "Thu 15 Oct 2026"),
        ])
    }

    @Test("Past the last nanosecond epoch, and past year 9999")
    func outOfRange() throws {
        let big = try #require(EpochText.problem(in: "9999999999999999999"))
        #expect(big.title == "Out of range: past the last nanosecond epoch")
        #expect(big.detail == "Nanoseconds stop at 2262-04-11 23:47:16 UTC (9223372036854775807).")
        let late = try #require(EpochText.problem(in: "999999999999", unit: .seconds))
        #expect(late.title == "Out of range: as seconds this is after the year 9999")
        #expect(EpochText.problem(in: "1792060800000") == nil)
    }

    // MARK: Zone-less date-time

    @Test("Zone-less input parses to a wall time")
    func parseLocal() throws {
        let local = try EpochParser.parseLocalDateTime("2026-10-25 01:30")
        #expect(local.time == LocalDateTime(date: CivilDate(2026, 10, 25), hour: 1, minute: 30))
        #expect(local.second == 0)
        #expect(try EpochParser.parseLocalDateTime("2026-10-25T01:30:15.250").nanoseconds == 250_000_000)
        #expect(throws: EpochError.invalidISO8601) { try EpochParser.parseLocalDateTime("2026-13-01 00:00") }
    }

    @Test("A repeated hour offers First and Second, with the note")
    func repeatedHour() throws {
        let local = try EpochParser.parseLocalDateTime("2026-10-25 01:30")
        let reading = EpochText.zoneless(local, in: Self.london, zoneName: "London")
        #expect(reading.options == [
            ZonelessOption(occurrence: .first, title: "First · BST", detail: "UTC+1 → 00:30 UTC",
                           value: EpochValue(seconds: 1_792_888_200, nanoseconds: 0)),
            ZonelessOption(occurrence: .second, title: "Second · GMT", detail: "UTC+0 → 01:30 UTC",
                           value: EpochValue(seconds: 1_792_891_800, nanoseconds: 0)),
        ])
        #expect(reading.note(for: .first) == "01:30 happens twice in London on Sun 25 Oct. Showing the first (BST). "
                + "Your scheduler may differ.")
        #expect(reading.note(for: .second) == "01:30 happens twice in London on Sun 25 Oct. Showing the second (GMT). "
                + "Your scheduler may differ.")
    }

    @Test("A skipped time moves to the next valid time; an ordinary one has no note")
    func skippedAndExact() throws {
        let gap = EpochText.zoneless(try EpochParser.parseLocalDateTime("2026-03-08 02:30"), in: Self.ny,
                                     zoneName: "New York")
        #expect(gap.options.map(\.value) == [EpochValue(seconds: 1_772_953_200, nanoseconds: 0)])   // 07:00Z
        #expect(gap.note(for: .first) == "02:30 doesn't exist in New York on Sun 8 Mar. Showing 03:00 EDT, "
                + "the next valid time. Your scheduler may differ.")
        let plain = EpochText.zoneless(try EpochParser.parseLocalDateTime("2026-10-15 10:40:30"), in: .utc,
                                       zoneName: "UTC")
        #expect(plain.options.map(\.value) == [EpochValue(seconds: 1_792_060_830, nanoseconds: 0)])
        #expect(plain.note(for: .first) == nil)
    }

    @Test("Time with abbreviation for the zone list")
    func zoneTime() {
        let instant = Self.utc("2026-10-15T10:40:00Z")
        #expect(ZoneClock.timeWithAbbreviation(instant, in: Self.london) == "11:40 BST")
        #expect(ZoneClock.timeWithAbbreviation(instant, in: Zone("Asia/Kathmandu")!) == "16:25 UTC+5:45")
    }
}

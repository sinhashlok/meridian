import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § CronParser / ScheduleEngine. Extra expected values
/// (Quartz L/W/#, Vixie star rule, DST days) were computed with Python.
@Suite("Cron")
struct CronTests {
    static let from = utc("2026-10-15T15:32:00Z")

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static func runs(_ text: String, _ dialect: CronDialect = .unix, in zone: Zone = .utc,
                     after: Date = from, count: Int = 5) throws -> [Date] {
        try CronExpression.parse(text, dialect: dialect).nextRuns(after: after, in: zone, count: count).map(\.instant)
    }

    static func instants(_ isoList: [String]) -> [Date] { isoList.map(utc) }

    // MARK: Fixture rows (from 2026-10-15T15:32Z, evaluated in UTC)

    @Test("0 2 * * * runs daily at 02:00")
    func daily() throws {
        #expect(try Self.runs("0 2 * * *") == Self.instants([
            "2026-10-16T02:00:00Z", "2026-10-17T02:00:00Z", "2026-10-18T02:00:00Z",
            "2026-10-19T02:00:00Z", "2026-10-20T02:00:00Z",
        ]))
        // 07:30 IST
        #expect(ZoneClock.wallTime(Self.utc("2026-10-16T02:00:00Z"), in: Zone("Asia/Kolkata")!) == "07:30")
    }

    @Test("0 2 * * 1-5 runs on weekdays")
    func weekdays() throws {
        #expect(try Self.runs("0 2 * * 1-5") == Self.instants([
            "2026-10-16T02:00:00Z", "2026-10-19T02:00:00Z", "2026-10-20T02:00:00Z",
            "2026-10-21T02:00:00Z", "2026-10-22T02:00:00Z",
        ]))
    }

    @Test("30 22 * * 0 is Sun 18 Oct 22:30Z = Mon 04:00 IST")
    func sunday() throws {
        let first = try #require(try Self.runs("30 22 * * 0", count: 1).first)
        #expect(first == Self.utc("2026-10-18T22:30:00Z"))
        let ist = Zone("Asia/Kolkata")!
        #expect(ZoneClock.wallTime(first, in: ist) == "04:00")
        #expect(ZoneClock.local(first, in: ist).date.isoWeekday == 1)
    }

    @Test("0 2 32 * * is a field 3 error with a caret on 32")
    func dayOfMonthError() {
        let text = "0 2 32 * *"
        #expect {
            try CronExpression.parse(text, dialect: .unix)
        } throws: { error in
            guard let error = error as? CronError else { return false }
            return error.message == "Field 3 · day-of-month: 32 is outside 1–31"
                && error.field == 3 && error.range.map { text[$0] } == "32"
        }
    }

    @Test("0 0 30 2 * is valid syntax but never runs")
    func neverRuns() throws {
        let expression = try CronExpression.parse("0 0 30 2 *", dialect: .unix)
        #expect(expression.nextRuns(after: Self.from, in: .utc, count: 5).isEmpty)
    }

    @Test("Unix ORs day-of-month and day-of-week when both are restricted")
    func unixOr() throws {
        #expect(try Self.runs("0 9 1 * 1") == Self.instants([
            "2026-10-19T09:00:00Z", "2026-10-26T09:00:00Z", "2026-11-01T09:00:00Z",
            "2026-11-02T09:00:00Z", "2026-11-09T09:00:00Z",
        ]))
    }

    @Test("Vixie rule: a day field starting with * is unrestricted, so */2 ANDs")
    func vixieStar() throws {
        #expect(try Self.runs("0 9 */2 * 1") == Self.instants([
            "2026-10-19T09:00:00Z", "2026-11-09T09:00:00Z", "2026-11-23T09:00:00Z",
            "2026-12-07T09:00:00Z", "2026-12-21T09:00:00Z",
        ]))
    }

    // MARK: Quartz

    @Test("Quartz equivalents of the fixture rows", arguments: [
        ("0 0 2 * * ?", "0 2 * * *"),
        ("0 0 2 ? * MON-FRI", "0 2 * * 1-5"),
        ("0 0 2 ? * 2-6", "0 2 * * 1-5"),          // Quartz MON=2 … FRI=6
        ("0 30 22 ? * 1", "30 22 * * 0"),          // Quartz SUN=1
        ("0 30 22 ? * SUN", "30 22 * * 0"),
    ])
    func quartzEquivalents(quartz: String, unix: String) throws {
        let expected = try Self.runs(unix)
        #expect(expected.count == 5)
        #expect(try Self.runs(quartz, .quartz) == expected)
    }

    @Test("Quartz numbers weekdays SUN=1…SAT=7, so 1-5 is Sunday to Thursday")
    func quartzNumbering() throws {
        #expect(try Self.runs("0 0 2 ? * 1-5", .quartz) == Self.instants([
            "2026-10-18T02:00:00Z", "2026-10-19T02:00:00Z", "2026-10-20T02:00:00Z",
            "2026-10-21T02:00:00Z", "2026-10-22T02:00:00Z",
        ]))
    }

    @Test("Quartz requires ? in exactly one day field", arguments: [
        "0 0 2 * * *", "0 0 2 1 * MON", "0 0 2 ? * ?",
    ])
    func quartzQuestionMark(text: String) {
        #expect(throws: CronError.self) { try CronExpression.parse(text, dialect: .quartz) }
    }

    @Test("Quartz L, L-3, W, LW, 6L and 6#3", arguments: [
        ("0 0 12 L * ?", ["2026-10-31T12:00:00Z", "2026-11-30T12:00:00Z"]),
        ("0 0 12 L-3 * ?", ["2026-10-28T12:00:00Z", "2026-11-27T12:00:00Z"]),
        ("0 0 12 15W * ?", ["2026-11-16T12:00:00Z", "2026-12-15T12:00:00Z"]),   // 15 Nov is a Sunday
        ("0 0 12 LW * ?", ["2026-10-30T12:00:00Z", "2026-11-30T12:00:00Z"]),    // 31 Oct is a Saturday
        ("0 0 12 ? * 6L", ["2026-10-30T12:00:00Z", "2026-11-27T12:00:00Z"]),    // last Friday
        ("0 0 12 ? * FRIL", ["2026-10-30T12:00:00Z", "2026-11-27T12:00:00Z"]),
        ("0 0 12 ? * 6#3", ["2026-10-16T12:00:00Z", "2026-11-20T12:00:00Z"]),   // third Friday
    ])
    func quartzSpecials(text: String, expected: [String]) throws {
        #expect(try Self.runs(text, .quartz, count: 2) == Self.instants(expected))
    }

    @Test("Quartz seconds and year fields")
    func quartzSecondsAndYear() throws {
        #expect(try Self.runs("15 30 10 * * ?", .quartz, count: 1) == Self.instants(["2026-10-16T10:30:15Z"]))
        #expect(try Self.runs("0 0 12 1 1 ? 2027", .quartz, count: 3) == Self.instants(["2027-01-01T12:00:00Z"]))
    }

    // MARK: Errors

    @Test("Errors name the field and point at the bad token", arguments: [
        ("61 * * * *", CronDialect.unix, "Field 1 · minute: 61 is outside 0–59", "61"),
        ("0 24 * * *", .unix, "Field 2 · hour: 24 is outside 0–23", "24"),
        ("0 2 * 13 *", .unix, "Field 4 · month: 13 is outside 1–12", "13"),
        ("0 2 * * 8", .unix, "Field 5 · day-of-week: 8 is outside 0–7", "8"),
        ("0 2 * * FOO", .unix, "Field 5 · day-of-week: FOO is not a day name or number", "FOO"),
        ("0 5-1 * * *", .unix, "Field 2 · hour: range 5-1 runs backwards", "5-1"),
        ("*/0 * * * *", .unix, "Field 1 · minute: step must be at least 1", "0"),
        ("0 2 ? * *", .unix, "Field 3 · day-of-month: ? is Quartz only", "?"),
        ("0 2 L * *", .unix, "Field 3 · day-of-month: L is Quartz only", "L"),
        ("0 0 2 ? * 8", .quartz, "Field 6 · day-of-week: 8 is outside 1–7", "8"),
        ("0 0 2 ? * 6#6", .quartz, "Field 6 · day-of-week: #6 is outside #1–#5", "6#6"),
    ])
    func fieldErrors(text: String, dialect: CronDialect, message: String, token: String) {
        #expect {
            try CronExpression.parse(text, dialect: dialect)
        } throws: { error in
            guard let error = error as? CronError else { return false }
            return error.message == message && error.range.map { String(text[$0]) } == token
        }
    }

    @Test("Wrong field counts", arguments: [
        ("0 2 * *", CronDialect.unix, "Unix cron needs 5 fields; found 4"),
        ("0 0 2 * * ?", .unix, "Unix cron needs 5 fields; found 6. Seconds need Quartz"),
        ("0 2 * * *", .quartz, "Quartz needs 6 or 7 fields; found 5"),
        ("", .unix, "Type a cron expression"),
    ])
    func fieldCounts(text: String, dialect: CronDialect, message: String) {
        #expect {
            try CronExpression.parse(text, dialect: dialect)
        } throws: { error in
            (error as? CronError)?.message == message
        }
    }

    // MARK: Syntax

    @Test("Names, lists, ranges, steps and macros", arguments: [
        ("0 2 * JAN,FEB MON-FRI", "0 2 * 1,2 1-5"),
        ("@daily", "0 0 * * *"),
        ("@hourly", "0 * * * *"),
        ("@weekly", "0 0 * * 0"),
        ("@monthly", "0 0 1 * *"),
        ("0 2 * * 7", "0 2 * * 0"),               // 7 is also Sunday
        ("0 9-17/4 * * *", "0 9,13,17 * * *"),
        ("5/20 * * * *", "5,25,45 * * * *"),
    ])
    func equivalent(text: String, same: String) throws {
        let expected = try Self.runs(same, count: 8)
        #expect(expected.count == 8)
        #expect(try Self.runs(text, count: 8) == expected)
    }

    // MARK: DST (spec §5.2) in America/New_York

    @Test("Skipped 02:30 runs at 03:00 EDT; repeated 01:30 runs once, first occurrence")
    func dstDaily() throws {
        let ny = Zone("America/New_York")!
        let spring = try CronExpression.parse("30 2 * * *", dialect: .unix)
            .nextRuns(after: Self.utc("2026-03-07T00:00:00Z"), in: ny, count: 3)
        #expect(spring.map(\.instant) == Self.instants([
            "2026-03-07T07:30:00Z", "2026-03-08T07:00:00Z", "2026-03-09T06:30:00Z",
        ]))
        #expect(spring.map(\.kind) == [.exact, .skipped, .exact])

        let fall = try CronExpression.parse("30 1 * * *", dialect: .unix)
            .nextRuns(after: Self.utc("2026-10-31T12:00:00Z"), in: ny, count: 2)
        #expect(fall.map(\.instant) == Self.instants(["2026-11-01T05:30:00Z", "2026-11-02T06:30:00Z"]))
        #expect(fall.map(\.kind) == [.repeated, .exact])
    }

    @Test("Hourly across both clock changes: no duplicate at 03:00, no second 01:00")
    func dstHourly() throws {
        let ny = Zone("America/New_York")!
        let hourly = try CronExpression.parse("0 * * * *", dialect: .unix)
        #expect(hourly.nextRuns(after: Self.utc("2026-03-08T04:30:00Z"), in: ny, count: 4).map(\.instant)
                == Self.instants(["2026-03-08T05:00:00Z", "2026-03-08T06:00:00Z",
                                  "2026-03-08T07:00:00Z", "2026-03-08T08:00:00Z"]))
        #expect(hourly.nextRuns(after: Self.utc("2026-11-01T03:30:00Z"), in: ny, count: 4).map(\.instant)
                == Self.instants(["2026-11-01T04:00:00Z", "2026-11-01T05:00:00Z",
                                  "2026-11-01T07:00:00Z", "2026-11-01T08:00:00Z"]))
    }

    // MARK: Description

    @Test("Plain-English descriptions", arguments: [
        ("0 2 * * *", CronDialect.unix, "At 02:00, every day"),
        ("0 2 * * 1-5", .unix, "At 02:00, Monday through Friday"),
        ("30 22 * * 0", .unix, "At 22:30, only on Sunday"),
        ("0 0 30 2 *", .unix, "At 00:00, on day 30 of the month, in February"),
        ("0 9 1 * 1", .unix, "At 09:00, on day 1 of the month and on Monday"),
        ("*/15 * * * *", .unix, "Every 15 minutes"),
        ("* * * * *", .unix, "Every minute"),
        ("0 * * * *", .unix, "At minute 0 of every hour"),
        ("0 9,17 * * 1,3,5", .unix, "At 09:00 and 17:00, on Monday, Wednesday and Friday"),
        ("0 0 12 L * ?", .quartz, "At 12:00, on the last day of the month"),
        ("0 15 10 ? * 6#3", .quartz, "At 10:15, on the third Friday of the month"),
        ("15 30 10 * * ?", .quartz, "At 10:30:15, every day"),
    ])
    func descriptions(text: String, dialect: CronDialect, expected: String) throws {
        #expect(try CronExpression.parse(text, dialect: dialect).description == expected)
    }
}

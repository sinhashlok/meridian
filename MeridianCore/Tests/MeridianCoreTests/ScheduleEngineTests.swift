import Foundation
import Testing
@testable import MeridianCore

/// Jobs schedule presets (spec §4.3), the monthly-job rows of docs/design/fixtures.md
/// § Conversions, and decision F (every N min/hours follow the wall clock).
@Suite("ScheduleEngine")
struct ScheduleEngineTests {
    static let from = utc("2026-10-15T15:32:00Z")
    static let ny = Zone("America/New_York")!
    static let london = Zone("Europe/London")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }
    static func instants(_ list: [String]) -> [Date] { list.map(utc) }

    static func runs(_ schedule: Schedule, in zone: Zone = .utc, after: Date = from, count: Int = 5) throws -> [ScheduledRun] {
        try ScheduleEngine.nextRuns(schedule, in: zone, after: after, count: count)
    }

    // MARK: Fixture rows

    @Test("Monthly day 1, 01:00 NY: 1 Nov 05:00Z (first occurrence, 10:30 IST), 1 Dec 06:00Z")
    func monthlyJobFixture() throws {
        let runs = try Self.runs(.monthly(day: .day(1), time: ClockTime(1, 0)), in: Self.ny, count: 2)
        #expect(runs.map(\.instant) == Self.instants(["2026-11-01T05:00:00Z", "2026-12-01T06:00:00Z"]))
        #expect(runs.map(\.kind) == [.repeated, .exact])
        let first = try #require(runs.first)
        #expect(ZoneClock.wallTime(first.instant, in: Zone("Asia/Kolkata")!) == "10:30")
    }

    // MARK: Presets

    @Test("Daily at one or more times; duplicates collapse")
    func daily() throws {
        #expect(try Self.runs(.daily(times: [ClockTime(2, 0)])).map(\.instant) == Self.instants([
            "2026-10-16T02:00:00Z", "2026-10-17T02:00:00Z", "2026-10-18T02:00:00Z",
            "2026-10-19T02:00:00Z", "2026-10-20T02:00:00Z",
        ]))
        #expect(try Self.runs(.daily(times: [ClockTime(14, 0), ClockTime(2, 0), ClockTime(2, 0)]), count: 4)
                    .map(\.instant) == Self.instants([
            "2026-10-16T02:00:00Z", "2026-10-16T14:00:00Z", "2026-10-17T02:00:00Z", "2026-10-17T14:00:00Z",
        ]))
    }

    @Test("Weekly Mon and Wed 09:00 London: 08:00Z in BST, 09:00Z after 25 Oct")
    func weekly() throws {
        let runs = try Self.runs(.weekly(days: [1, 3], time: ClockTime(9, 0)), in: Self.london, count: 4)
        #expect(runs.map(\.instant) == Self.instants([
            "2026-10-19T08:00:00Z", "2026-10-21T08:00:00Z", "2026-10-26T09:00:00Z", "2026-10-28T09:00:00Z",
        ]))
    }

    @Test("Monthly day 31 skips shorter months")
    func monthly31() throws {
        #expect(try Self.runs(.monthly(day: .day(31), time: ClockTime(12, 0)), count: 4).map(\.instant) == Self.instants([
            "2026-10-31T12:00:00Z", "2026-12-31T12:00:00Z", "2027-01-31T12:00:00Z", "2027-03-31T12:00:00Z",
        ]))
    }

    @Test("Monthly Last runs on the last day of every month")
    func monthlyLast() throws {
        #expect(try Self.runs(.monthly(day: .last, time: ClockTime(12, 0))).map(\.instant) == Self.instants([
            "2026-10-31T12:00:00Z", "2026-11-30T12:00:00Z", "2026-12-31T12:00:00Z",
            "2027-01-31T12:00:00Z", "2027-02-28T12:00:00Z",
        ]))
    }

    @Test("Every 15 min follows the wall clock (decision F)")
    func everyMinutes() throws {
        #expect(try Self.runs(.everyMinutes(15), count: 3).map(\.instant) == Self.instants([
            "2026-10-15T15:45:00Z", "2026-10-15T16:00:00Z", "2026-10-15T16:15:00Z",
        ]))
    }

    @Test("Every 2 hours in New York across both clock changes")
    func everyHoursAcrossDST() throws {
        let spring = try Self.runs(.everyHours(2), in: Self.ny, after: Self.utc("2026-03-08T04:30:00Z"), count: 3)
        #expect(spring.map(\.instant) == Self.instants([
            "2026-03-08T05:00:00Z", "2026-03-08T07:00:00Z", "2026-03-08T08:00:00Z",
        ]))
        #expect(spring.map(\.kind) == [.exact, .skipped, .exact])

        let fall = try Self.runs(.everyHours(2), in: Self.ny, after: Self.utc("2026-11-01T03:30:00Z"), count: 3)
        #expect(fall.map(\.instant) == Self.instants([
            "2026-11-01T04:00:00Z", "2026-11-01T07:00:00Z", "2026-11-01T09:00:00Z",
        ]))
    }

    @Test("Cron schedules use CronParser; never-running ones return no runs")
    func cron() throws {
        #expect(try Self.runs(.cron(dialect: .unix, expression: "0 2 * * 1-5"), count: 2).map(\.instant)
                == Self.instants(["2026-10-16T02:00:00Z", "2026-10-19T02:00:00Z"]))
        #expect(try Self.runs(.cron(dialect: .unix, expression: "0 0 30 2 *")).isEmpty)
    }

    // MARK: Validation

    @Test("Invalid schedules throw", arguments: [
        (Schedule.everyMinutes(7), ScheduleError.invalidInterval(7, allowed: ScheduleEngine.minuteIntervals)),
        (.everyMinutes(0), .invalidInterval(0, allowed: ScheduleEngine.minuteIntervals)),
        (.everyHours(5), .invalidInterval(5, allowed: ScheduleEngine.hourIntervals)),
        (.daily(times: []), .noTimes),
        (.weekly(days: [], time: ClockTime(9, 0)), .noDays),
        (.weekly(days: [8], time: ClockTime(9, 0)), .noDays),
        (.monthly(day: .day(0), time: ClockTime(9, 0)), .invalidDay(0)),
        (.monthly(day: .day(32), time: ClockTime(9, 0)), .invalidDay(32)),
    ])
    func invalid(schedule: Schedule, error: ScheduleError) {
        #expect(throws: error) { try ScheduleEngine.nextRuns(schedule, in: .utc, after: Self.from, count: 1) }
    }

    @Test("Bad cron text surfaces the CronError")
    func badCron() {
        #expect {
            try ScheduleEngine.nextRuns(.cron(dialect: .unix, expression: "0 2 32 * *"), in: .utc, after: Self.from, count: 1)
        } throws: { error in
            guard case .cron(let cronError) = error as? ScheduleError else { return false }
            return cronError.message == "Field 3 · day-of-month: 32 is outside 1–31"
        }
    }

    // MARK: Schedule line (always in the job's zone)

    @Test("Schedule lines", arguments: [
        (Schedule.daily(times: [ClockTime(2, 0)]), Zone.utc, "Daily · 02:00 UTC"),
        (.daily(times: [ClockTime(14, 0), ClockTime(2, 0)]), .utc, "Daily · 02:00, 14:00 UTC"),
        (.weekly(days: [1, 3], time: ClockTime(9, 0)), london, "Weekly · Mon, Wed 09:00 London"),
        (.weekly(days: [1, 2, 3, 4, 5], time: ClockTime(9, 0)), london, "Weekly · Mon–Fri 09:00 London"),
        (.monthly(day: .day(1), time: ClockTime(1, 0)), ny, "Monthly · day 1 · 01:00 New York"),
        (.monthly(day: .last, time: ClockTime(23, 30)), ny, "Monthly · last day · 23:30 New York"),
        (.everyMinutes(15), .utc, "Every 15 min"),
        (.everyHours(2), ny, "Every 2 hours · from 00:00 New York"),
        (.cron(dialect: .unix, expression: "0 2 * * 1-5"), .utc, "Cron · 0 2 * * 1-5 · UTC"),
        (.weekly(days: [7], time: ClockTime(3, 0)), .utc, "Weekly · Sun 03:00 UTC"),
        (.everyHours(4), .utc, "Every 4 hours · from 00:00 UTC"),
    ])
    func scheduleLine(schedule: Schedule, zone: Zone, line: String) {
        #expect(ScheduleEngine.scheduleLine(schedule, in: zone) == line)
    }

    // MARK: Warnings

    @Test("Monthly day 29–31 warn about the months they skip", arguments: [
        (31, "Skips months without day 31"),
        (30, "Skips February"),
        (29, "Skips February except in leap years"),
    ])
    func monthlyWarnings(day: Int, message: String) {
        let warnings = ScheduleEngine.warnings(.monthly(day: .day(day), time: ClockTime(9, 0)), in: .utc, runs: [])
        #expect(warnings.map(\.message) == [message])
    }

    @Test("DST warnings name the reading used")
    func dstWarnings() throws {
        let repeated = try Self.runs(.monthly(day: .day(1), time: ClockTime(1, 0)), in: Self.ny, count: 1)
        #expect(ScheduleEngine.warnings(.monthly(day: .day(1), time: ClockTime(1, 0)), in: Self.ny, runs: repeated)
                    .map(\.message) == [
            "Sun 1 Nov: 01:00 happens twice in New York; this uses the first, 01:00 EDT (UTC−4). Your scheduler may differ.",
        ])

        let schedule = Schedule.daily(times: [ClockTime(2, 30)])
        let skipped = try Self.runs(schedule, in: Self.ny, after: Self.utc("2026-03-08T00:00:00Z"), count: 1)
        #expect(ScheduleEngine.warnings(schedule, in: Self.ny, runs: skipped).map(\.message) == [
            "Sun 8 Mar: 02:30 doesn't exist in New York, so this run is at 03:00 EDT (UTC−4). Your scheduler may differ.",
        ])
    }

    @Test("Short date text and zone city names")
    func helpers() {
        #expect(CivilDate(2026, 10, 26).shortText == "Mon 26 Oct")
        #expect(Self.ny.cityName == "New York")
        #expect(Zone("America/Argentina/Buenos_Aires")!.cityName == "Buenos Aires")
        #expect(Zone.utc.cityName == "UTC")
    }
}

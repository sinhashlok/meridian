import Foundation
import Testing
@testable import MeridianCore

/// Tools › Cron wording (boards Cron and CronError; spec §4.6; decision AF).
/// Run instants come from the fixture-tested `CronExpression`; checked with Python.
@Suite("Cron text")
struct CronTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let ny = Zone("America/New_York")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }
    static let boardNow = utc("2026-10-15T15:32:00Z")

    @Test("Field chips with labels; the error field is marked")
    func chips() {
        #expect(CronText.fieldChips("0 2 32 * *", dialect: .unix, errorField: 3) == [
            CronFieldChip(text: "0", label: "min", isError: false),
            CronFieldChip(text: "2", label: "hour", isError: false),
            CronFieldChip(text: "32", label: "day", isError: true),
            CronFieldChip(text: "*", label: "month", isError: false),
            CronFieldChip(text: "*", label: "weekday", isError: false),
        ])
        #expect(CronText.fieldChips("0 0 12 ? * MON-FRI", dialect: .quartz, errorField: nil).map(\.label)
                == ["sec", "min", "hour", "day", "month", "weekday"])
        #expect(CronText.fieldChips("@daily", dialect: .unix, errorField: nil)
                == [CronFieldChip(text: "@daily", label: "macro", isError: false)])
        #expect(CronText.fieldChips("0 2 * * * *", dialect: .unix, errorField: nil).last?.label == "extra")
        #expect(CronText.fieldLabels(.unix) == "min · hour · day · month · weekday")
    }

    @Test("Hints after an error")
    func hints() {
        func hint(_ text: String, _ dialect: CronDialect) -> String? {
            do { _ = try CronExpression.parse(text, dialect: dialect); return nil } catch {
                return CronText.hint(for: error, dialect: dialect)
            }
        }
        #expect(hint("0 2 32 * *", .unix) == "Unix cron has no “last day” value. Use 28–31, or switch the dialect to Quartz for L.")
        #expect(hint("0 2 L * *", .unix) == "Switch the dialect to Quartz to use L, W and #.")
        #expect(hint("0 2 * * 9", .unix) == nil)
    }

    @Test("Run rows: UTC and the phone's local time")
    func runRows() throws {
        let runs = try CronExpression.parse("0 2 * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 5)
        #expect(runs.map { CronText.runRow($0, device: Self.ist) } == [
            CronRunRow(utc: "Fri 16 Oct 02:00", local: "Fri 07:30"),
            CronRunRow(utc: "Sat 17 Oct 02:00", local: "Sat 07:30"),
            CronRunRow(utc: "Sun 18 Oct 02:00", local: "Sun 07:30"),
            CronRunRow(utc: "Mon 19 Oct 02:00", local: "Mon 07:30"),
            CronRunRow(utc: "Tue 20 Oct 02:00", local: "Tue 07:30"),
        ])
        let sunday = try CronExpression.parse("30 22 * * 0", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 1)
        #expect(CronText.runRow(sunday[0], device: Self.ist) == CronRunRow(utc: "Sun 18 Oct 22:30", local: "Mon 04:00"))
        #expect(CronText.localHeader(device: Self.ist, at: Self.boardNow) == "Local · IST")
    }

    @Test("Phone note: one local time for every run")
    func phoneNote() throws {
        let daily = try CronExpression.parse("0 2 * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 5)
        #expect(CronText.phoneNote(runs: daily, evaluateIn: .utc, device: Self.ist)
                == "Servers usually schedule in UTC. That is 07:30 on this phone.")
        let hourly = try CronExpression.parse("0 * * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 5)
        #expect(CronText.phoneNote(runs: hourly, evaluateIn: .utc, device: Self.ist) == "Servers usually schedule in UTC.")
        let inNY = try CronExpression.parse("0 9 * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: Self.ny, count: 5)
        #expect(CronText.phoneNote(runs: inNY, evaluateIn: Self.ny, device: Self.ist) == "That is 18:30 on this phone.")
        #expect(CronText.phoneNote(runs: daily, evaluateIn: .utc, device: .utc) == "Servers usually schedule in UTC.")
    }

    @Test("DST notes name the run the gap/overlap rule moved")
    func dstNotes() throws {
        let spring = try CronExpression.parse("30 2 * * *", dialect: .unix)
            .nextRuns(after: Self.utc("2026-03-07T12:00:00Z"), in: Self.ny, count: 5)
        #expect(CronText.dstNote(runs: spring, zone: Self.ny, zoneName: "New York")
                == "Sun 8 Mar 02:30 doesn't exist in New York; that run is at 03:00 EDT. Your scheduler may differ.")
        let autumn = try CronExpression.parse("30 1 * * *", dialect: .unix)
            .nextRuns(after: Self.utc("2026-10-31T12:00:00Z"), in: Self.ny, count: 5)
        #expect(CronText.dstNote(runs: autumn, zone: Self.ny, zoneName: "New York")
                == "Sun 1 Nov 01:30 happens twice in New York; it runs once, at the first (EDT). Your scheduler may differ.")
        let daily = try CronExpression.parse("0 2 * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 5)
        #expect(CronText.dstNote(runs: daily, zone: .utc, zoneName: "UTC") == nil)
    }

    @Test("Never runs, and copy text with offsets")
    func neverAndCopy() throws {
        #expect(CronText.neverRuns == EpochNote(title: "Never runs",
                                                detail: "The syntax is valid, but no date in the next 400 years matches it."))
        let runs = try CronExpression.parse("0 2 * * *", dialect: .unix).nextRuns(after: Self.boardNow, in: .utc, count: 2)
        #expect(CronText.copyText(expression: "0 2 * * *", description: "At 02:00, every day", runs: runs, device: Self.ist)
                == "0 2 * * * · At 02:00, every day\nFri 16 Oct 2026 02:00 UTC · 07:30 IST (UTC+5:30)\n"
                + "Sat 17 Oct 2026 02:00 UTC · 07:30 IST (UTC+5:30)")
    }
}

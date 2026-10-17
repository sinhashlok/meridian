import Foundation
import Testing
@testable import MeridianCore

/// Boards JobsList, JobDetail, JobDetailScrolled and JobEdit (phone in IST, Thu 15 Oct
/// 2026 15:32:07Z = 21:02 IST), fixtures.md's monthly New York job, decisions BJ–BM.
/// Board JobDetail says "96 days ago" for 12 Jul; it is 95 days (checked with Python).
@Suite("Job text")
struct JobTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let now = utc("2026-10-15T15:32:07Z")
    static let today = CivilDate(2026, 10, 15)

    static func utc(_ iso: String) -> Date {
        try! EpochParser.parseISO8601(iso).date
    }

    static let marketing = Job(title: "Marketing dashboard refresh", category: .dashboard,
                               schedule: .everyHours(4), lastReviewed: CivilDate(2026, 10, 1))
    static let netsuite = Job(
        title: "Netsuite pipeline run",
        notes: "Loads NetSuite GL, AR and AP into the lakehouse each night, then rebuilds the sales views.",
        category: .pipeline, mirrors: "Airflow DAG netsuite_nightly", schedule: .daily(times: [ClockTime(2, 0)]),
        remindsMe: true, lastReviewed: CivilDate(2026, 7, 12),
        children: [Job.Child(name: "Bronze load", offsetMinutes: 0), Job.Child(name: "Silver transform", offsetMinutes: 20),
                   Job.Child(name: "Gold views", offsetMinutes: 45),
                   Job.Child(name: "Sales dashboard refresh", offsetMinutes: 90)])
    static let monthEnd = Job(title: "Month-end close extract", category: .extract,
                              schedule: .monthly(day: .day(1), time: ClockTime(1, 0)), zoneID: "America/New_York",
                              remindsMe: true, lastReviewed: CivilDate(2026, 9, 1))
    static let legacy = Job(title: "Legacy CRM sync", category: .other,
                            schedule: .weekly(days: [7], time: ClockTime(3, 0)), isPaused: true,
                            lastReviewed: CivilDate(2026, 9, 1))
    static let board = [marketing, netsuite, monthEnd, legacy]

    @Test("JobsList rows")
    func rows() {
        let rows = Self.board.map { JobText.row($0, now: Self.now, display: Self.ist, device: Self.ist) }
        #expect(rows.map(\.scheduleLine) == ["Every 4 hours · from 00:00 UTC", "Daily · 02:00 UTC · 4 children",
                                             "Monthly · day 1 · 01:00 New York", "Weekly · Sun 03:00 UTC"])
        #expect(rows.map(\.next) == ["Next 21:30 IST today", "Next Fri 07:30 IST", "Next Sun 1 Nov 10:30 IST", nil])
        #expect(rows.map(\.countdown) == ["in 28 min", "in 10h 28m", "in 16 days", nil])
        #expect(rows.map(\.countdownIsSoon) == [true, true, false, false])
        #expect(rows.map(\.needsReview) == [false, true, false, false])
        #expect(rows.map(\.dstBadge) == [nil, nil, "DST 1 Nov", nil])
    }

    @Test("The Next line follows the UTC pill")
    func utcDisplay() {
        #expect(JobText.row(Self.marketing, now: Self.now, display: .utc, device: Self.ist).next
                == "Next 16:00 UTC today")
    }

    @Test("Groups: Next 24 hours, Later, Paused, each by next run")
    func groups() {
        let groups = JobText.groups([Self.legacy, Self.monthEnd, Self.netsuite, Self.marketing], now: Self.now)
        #expect(groups.map(\.group) == [.next24Hours, .later, .paused])
        #expect(groups.map { $0.jobs.map(\.title) } == [
            ["Marketing dashboard refresh", "Netsuite pipeline run"], ["Month-end close extract"], ["Legacy CRM sync"],
        ])
        #expect(groups.map(\.group.title) == ["Next 24 hours", "Later", "Paused"])
    }

    @Test("Header", arguments: [
        (4, "IST", "4 jobs · times in IST"), (1, "UTC", "1 job · times in UTC"),
    ] as [(Int, String, String)])
    func header(count: Int, zone: String, expected: String) {
        let display = zone == "UTC" ? Zone.utc : Self.ist
        #expect(JobText.header(count: count, display: display, now: Self.now) == expected)
    }

    @Test("Countdown: rounded up under 24 h, whole days after", arguments: [
        (27 * 60 + 53, "in 28 min"), (10 * 3600 + 27 * 60 + 53, "in 10h 28m"), (2 * 3600, "in 2h"),
        (30, "in 1 min"), (36 * 3600, "in 1 day"), (16 * 86_400 + 13 * 3600, "in 16 days"),
    ] as [(Int, String)])
    func countdown(seconds: Int, expected: String) {
        #expect(JobText.countdown(to: Self.now + TimeInterval(seconds), now: Self.now).text == expected)
    }

    @Test("Review after 90 days; JobDetail lines")
    func review() {
        #expect(JobText.reviewBanner(Self.netsuite, today: Self.today) == "Last reviewed 12 Jul 2026 · 95 days ago")
        #expect(JobText.reviewedLine(Self.netsuite, today: Self.today) == "Reviewed 12 Jul 2026 · 95 days ago")
        #expect(JobText.reviewBanner(Self.monthEnd, today: Self.today) == nil)
        let fresh = Job(title: "x", schedule: .everyMinutes(15), lastReviewed: Self.today)
        #expect(JobText.reviewedLine(fresh, today: Self.today) == "Reviewed 15 Oct 2026 · today")
    }

    @Test("JobDetail schedule card")
    func scheduleCard() {
        let card = JobText.scheduleCard(Self.netsuite, now: Self.now, display: Self.ist, device: Self.ist)
        #expect(card.title == "Daily · 02:00 UTC")
        #expect(card.phoneLine == "07:30 IST on this phone")
        #expect(card.nextRun == "Fri 16 Oct · 07:30 IST")
        #expect(card.countdown == "in 10h 28m")
        let paused = JobText.scheduleCard(Self.legacy, now: Self.now, display: Self.ist, device: Self.ist)
        #expect(paused.nextRun == nil)
        #expect(JobText.scheduleCard(Self.marketing, now: Self.now, display: Self.ist, device: Self.ist).phoneLine
                == nil)
    }

    @Test("Monthly 01:00 New York: 1 Nov 05:00Z (first occurrence), then 1 Dec 06:00Z")
    func monthlyFixture() {
        let runs = Self.monthEnd.nextRuns(after: Self.now, count: 2)
        #expect(runs.map(\.instant) == [Self.utc("2026-11-01T05:00:00Z"), Self.utc("2026-12-01T06:00:00Z")])
        #expect(runs.first?.kind == .repeated)
    }

    @Test("JobDetailScrolled: children expected at")
    func children() {
        let rows = JobText.childRows(Self.netsuite, now: Self.now, display: Self.ist)
        #expect(rows.map(\.offset) == ["+0:00", "+0:20", "+0:45", "+1:30"])
        #expect(rows.map(\.expected) == ["07:30 IST", "07:50 IST", "08:15 IST", "09:00 IST"])
        #expect(JobText.childrenHeader(Self.netsuite) == "Children · 4 · expected at")
    }

    @Test("JobEdit lines under the zone row")
    func editLines() {
        #expect(JobText.editPreview(Self.netsuite, now: Self.now, device: Self.ist)
                == "07:30 IST on this phone · next run Fri 16 Oct")
        #expect(JobText.zoneLine(Zone("America/New_York")!, now: Self.now) == "America/New_York · EDT now, EST from 1 Nov")
        #expect(JobText.zoneLine(Self.ist, now: Self.now) == "Asia/Kolkata · IST all year")
        #expect(JobText.zoneLine(.utc, now: Self.now) == "UTC · no clock changes")
    }

    @Test("Offsets", arguments: [
        (0, "+0:00"), (45, "+0:45"), (90, "+1:30"), (1439, "+23:59"),
    ] as [(Int, String)])
    func offset(minutes: Int, expected: String) {
        #expect(JobText.offsetText(minutes) == expected)
    }

    @Test("JSON round trip, cron schedule included")
    func codable() throws {
        var job = Self.netsuite
        job.schedule = .cron(dialect: .quartz, expression: "0 0 1 ? * MON")
        #expect(try JSONDecoder().decode(Job.self, from: JSONEncoder().encode(job)) == job)
    }

    @Test("JobsNotifOff banner counts unpaused jobs with reminders")
    func notificationsOff() {
        #expect(JobText.notificationsOffDetail(Self.board) == "Reminders for 2 jobs won't arrive.")
        #expect(JobText.notificationsOffDetail([Self.netsuite]) == "Reminders for 1 job won't arrive.")
        #expect(JobText.notificationsOffDetail([Self.marketing, Self.legacy]) == nil)
    }

    @Test("Schedule problems shown in the edit sheet")
    func scheduleProblems() throws {
        #expect(JobText.scheduleProblem(.noTimes) == "Add at least one time.")
        #expect(JobText.scheduleProblem(.noDays) == "Pick at least one day.")
        let cron = try #require(Self.cronError("0 2 32 * *"))
        #expect(JobText.scheduleProblem(.cron(cron)) == cron.message)
    }

    @Test("Lead time labels", arguments: [(0, "At the run"), (10, "10 min"), (60, "1 hour")] as [(Int, String)])
    func leadText(minutes: Int, expected: String) {
        #expect(JobText.leadText(minutes) == expected)
    }

    static func cronError(_ text: String) -> CronError? {
        do { _ = try CronExpression.parse(text, dialect: .unix); return nil } catch { return error }
    }
}

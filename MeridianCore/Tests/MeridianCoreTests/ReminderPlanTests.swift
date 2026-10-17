import Foundation
import Testing
@testable import MeridianCore

/// Decision BK: job reminders are local notifications in a rolling 48-hour window,
/// capped so Meridian stays inside iOS's 64 pending notifications.
@Suite("Reminder plan")
struct ReminderPlanTests {
    static let ist = Zone("Asia/Kolkata")!
    static let now = JobTextTests.now   // Thu 15 Oct 2026 15:32:07Z

    static func utc(_ iso: String) -> Date {
        try! EpochParser.parseISO8601(iso).date
    }

    @Test("Netsuite (daily 02:00 UTC, 10 min lead): two reminders in the next 48 hours")
    func netsuite() {
        let job = JobTextTests.netsuite
        let reminders = ReminderPlan.wanted([job], now: Self.now, device: Self.ist)
        #expect(reminders.map(\.fireDate) == [Self.utc("2026-10-16T01:50:00Z"), Self.utc("2026-10-17T01:50:00Z")])
        #expect(reminders.map(\.identifier) == ["job-\(job.id.uuidString)-1792116000",
                                                "job-\(job.id.uuidString)-1792202400"])
        #expect(reminders.first?.title == "Netsuite pipeline run in 10 min")
        #expect(reminders.first?.body == "Expected at 07:30 IST · Daily · 02:00 UTC")
    }

    @Test("Paused jobs, reminders off and runs past the window get none")
    func excluded() {
        var off = JobTextTests.marketing
        off.remindsMe = false
        let jobs = [JobTextTests.legacy, off, JobTextTests.monthEnd]   // month-end runs on 1 Nov
        #expect(ReminderPlan.wanted(jobs, now: Self.now, device: Self.ist).isEmpty)
    }

    @Test("A reminder whose time has passed is skipped even if the run hasn't")
    func leadPassed() {
        let job = Job(title: "Quarter-hour", schedule: .everyMinutes(15), remindsMe: true, reminderLeadMinutes: 15,
                      lastReviewed: JobTextTests.today)
        // The 15:45Z run's reminder was due at 15:30Z, before now.
        let first = ReminderPlan.wanted([job], now: Self.now, device: Self.ist).first
        #expect(first?.fireDate == Self.utc("2026-10-15T15:45:00Z"))
        #expect(first?.title == "Quarter-hour in 15 min")
    }

    @Test("Lead 0 says now")
    func atRun() {
        let job = Job(title: "Refresh", schedule: .everyHours(4), remindsMe: true, reminderLeadMinutes: 0,
                      lastReviewed: JobTextTests.today)
        #expect(ReminderPlan.wanted([job], now: Self.now, device: Self.ist).first?.title == "Refresh now")
    }

    @Test("50 jobs every 15 minutes: exactly 48 reminders, soonest first (stays within 64)")
    func budget() {
        let jobs = (0..<50).map { index in
            Job(title: "Job \(index)", schedule: .everyMinutes(15), remindsMe: true, reminderLeadMinutes: 5,
                lastReviewed: JobTextTests.today)
        }
        let reminders = ReminderPlan.wanted(jobs, now: Self.now, device: Self.ist)
        #expect(reminders.count == ReminderPlan.budget)
        #expect(ReminderPlan.budget == 48)
        #expect(reminders.map(\.fireDate) == reminders.map(\.fireDate).sorted())
        #expect(reminders.first?.fireDate == Self.utc("2026-10-15T15:40:00Z"))
        #expect(Set(reminders.map(\.identifier)).count == reminders.count)
    }

    @Test("Diff: keep matching, remove stale, add missing; other prefixes untouched")
    func diff() throws {
        let wanted = ReminderPlan.wanted([JobTextTests.netsuite], now: Self.now, device: Self.ist)
        try #require(wanted.count == 2)
        let pending: Set<String> = [wanted[0].identifier, "job-stale-1", "timer-ABC"]
        let plan = ReminderPlan.diff(wanted: wanted, pending: pending)
        #expect(plan.remove == ["job-stale-1"])
        #expect(plan.add == [wanted[1]])
    }
}

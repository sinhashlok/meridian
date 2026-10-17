import Foundation
import Testing
@testable import MeridianCore

/// Decisions AH (one alarm per running timer), AQ (Live Activity content) and AR
/// (reconcile with what AlarmKit reports, on launch and when the app becomes active).
@Suite("Timer alarm plan")
struct TimerAlarmPlanTests {
    static let ist = Zone("Asia/Kolkata")!
    static let now = try! EpochParser.parseISO8601("2026-10-15T15:39:18Z").date

    static func id(_ n: Int) -> UUID { UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")! }

    static func standup() -> CountdownTimer {
        .duration(seconds: 600, name: "Standup prep", id: id(1), now: now.addingTimeInterval(-198))
    }

    static func deploy() -> CountdownTimer {
        .until(hour: 2, minute: 0, in: .utc, occurrence: .first, name: "Deploy window", id: id(2), now: now)
    }

    // MARK: Reconcile (decision AR)

    @Test("Keep matching alarms, schedule missing ones, cancel the rest")
    func reconcile() {
        var paused = CountdownTimer.duration(seconds: 600, id: Self.id(4), now: Self.now)
        paused.pause(at: Self.now)
        let finished = CountdownTimer.duration(seconds: 60, id: Self.id(5), now: Self.now.addingTimeInterval(-120))
        let entries = [
            TimerAlarmPlan.Entry(timer: Self.standup(), alarmID: Self.id(101)),              // fine
            TimerAlarmPlan.Entry(timer: Self.deploy(), alarmID: nil),                        // never scheduled
            TimerAlarmPlan.Entry(timer: .duration(seconds: 90, id: Self.id(3), now: Self.now),
                                 alarmID: Self.id(103)),                                     // alarm vanished
            TimerAlarmPlan.Entry(timer: paused, alarmID: Self.id(104)),                      // paused: no alarm
            TimerAlarmPlan.Entry(timer: finished, alarmID: Self.id(105)),                    // rang and stopped
        ]
        let scheduled: Set<UUID> = [Self.id(101), Self.id(104), Self.id(999)]
        let plan = TimerAlarmPlan.reconcile(entries, scheduled: scheduled, now: Self.now)
        #expect(Set(plan.cancel) == [Self.id(104), Self.id(999)])
        #expect(plan.schedule == [Self.id(2), Self.id(3)])
        #expect(plan.clear == [Self.id(4), Self.id(5)])
    }

    @Test("Nothing to do when everything matches")
    func reconcileClean() {
        let plan = TimerAlarmPlan.reconcile([TimerAlarmPlan.Entry(timer: Self.standup(), alarmID: Self.id(101))],
                                            scheduled: [Self.id(101)], now: Self.now)
        #expect(plan.isEmpty)
    }

    // MARK: Live Activity content (decision AQ)

    @Test("Board timers: Standup prep is soonest, +1 more")
    func activityBoard() {
        let content = TimerAlarmPlan.activity([Self.deploy(), Self.standup()], now: Self.now, display: Self.ist)
        #expect(content == TimerActivityContent(
            title: "Standup prep", caption: "Ends 21:16 IST",
            endDate: try! EpochParser.parseISO8601("2026-10-15T15:46:00Z").date,
            progressStart: try! EpochParser.parseISO8601("2026-10-15T15:36:00Z").date,
            pausedRemaining: nil, pausedFraction: nil, more: "+1 more"))
    }

    @Test("Until alone: no progress bar, Until caption")
    func activityUntil() {
        let content = TimerAlarmPlan.activity([Self.deploy()], now: Self.now, display: Self.ist)
        #expect(content?.title == "Deploy window")
        #expect(content?.caption == "Until 02:00 UTC")
        #expect(content?.progressStart == nil)
        #expect(content?.more == nil)
    }

    @Test("Only paused timers: static remaining and bar")
    func activityPaused() {
        var timer = Self.standup()
        timer.pause(at: Self.now)
        let content = TimerAlarmPlan.activity([timer], now: Self.now, display: Self.ist)
        #expect(content?.caption == "Paused")
        #expect(content?.endDate == nil)
        #expect(content?.pausedRemaining == "06:42")
        #expect(content?.pausedFraction == 0.67)
    }

    @Test("Running beats paused; finished timers don't count; none left ends it")
    func activityRunningFirst() {
        var paused = CountdownTimer.duration(seconds: 30, name: "short", now: Self.now)
        paused.pause(at: Self.now)
        let finished = CountdownTimer.duration(seconds: 60, now: Self.now.addingTimeInterval(-120))
        let content = TimerAlarmPlan.activity([paused, finished, Self.deploy()], now: Self.now, display: Self.ist)
        #expect(content?.title == "Deploy window")
        #expect(content?.more == "+1 more")
        #expect(TimerAlarmPlan.activity([finished], now: Self.now, display: Self.ist) == nil)
    }
}

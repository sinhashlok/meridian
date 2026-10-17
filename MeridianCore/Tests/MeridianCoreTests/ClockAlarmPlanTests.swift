import Foundation
import Testing
@testable import MeridianCore

/// Decisions BD (Local = one relative alarm; zoned = fixed rings for 14 days) and BF
/// (one-off alarms turn off after ringing): what to cancel and schedule for one alarm.
@Suite("Clock alarm plan")
struct ClockAlarmPlanTests {
    static let ist = AlarmTests.ist
    static let now = AlarmTests.boardNow   // Fri 16 Oct 2026 10:15:07Z

    static func id(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))! }

    static let wake = AlarmTests.alarm(7, 45, zone: nil)
    static let market = AlarmTests.alarm(9, 0, zone: AlarmTests.ny)

    static func step(_ alarm: ClockAlarm, _ scheduled: ClockAlarmPlan.Scheduled = .none, live: Set<UUID> = [],
                     at now: Date = now) -> ClockAlarmPlan.Step {
        ClockAlarmPlan.step(for: alarm, scheduled: scheduled, live: live, now: now, device: Self.ist)
    }

    @Test("Local alarm: one relative alarm, kept while live and unchanged")
    func local() {
        let fresh = Self.step(Self.wake)
        #expect(fresh.scheduleRelative && fresh.scheduleFixed.isEmpty && fresh.cancel.isEmpty)
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: Self.wake.fingerprint, relative: Self.id(1))
        #expect(Self.step(Self.wake, scheduled, live: [Self.id(1)]) == ClockAlarmPlan.Step(kept: scheduled))
    }

    @Test("A changed alarm cancels what was scheduled and starts again")
    func changed() {
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: Self.wake.fingerprint, relative: Self.id(1))
        var later = Self.wake
        later.time = ClockTime(8, 0)
        let step = Self.step(later, scheduled, live: [Self.id(1)])
        #expect(step.cancel == [Self.id(1)])
        #expect(step.scheduleRelative)
        #expect(step.kept == ClockAlarmPlan.Scheduled(fingerprint: later.fingerprint))
    }

    @Test("Zoned alarm: fixed rings for 14 days; only missing ones are scheduled")
    func zoned() {
        let fresh = Self.step(Self.market)
        #expect(fresh.scheduleFixed.count == 10)
        #expect(!fresh.scheduleRelative)

        let rings = Self.market.rings(after: Self.now, within: ClockAlarm.window, device: Self.ist)
        var fixed = Dictionary(uniqueKeysWithValues: rings.enumerated().map { (Self.id($0.offset + 1), $0.element) })
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: Self.market.fingerprint, fixed: fixed)
        let live = Set(fixed.keys).subtracting([Self.id(3)])          // the system dropped one
        let step = Self.step(Self.market, scheduled, live: live)
        #expect(step.cancel == [Self.id(3)])
        #expect(step.scheduleFixed == [rings[2]])
        fixed[Self.id(3)] = nil
        #expect(step.kept.fixed == fixed)
    }

    @Test("Off: everything cancelled")
    func off() {
        var alarm = Self.market
        alarm.isOn = false
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: alarm.fingerprint, fixed: [Self.id(1): Self.now + 3600])
        let step = Self.step(alarm, scheduled, live: [Self.id(1)])
        #expect(step.cancel == [Self.id(1)])
        #expect(step.scheduleFixed.isEmpty && !step.scheduleRelative && !step.turnOff)
    }

    @Test("A ring that is alerting or snoozed (past, still live) is left alone")
    func ringing() {
        let past = AlarmTests.utc("2026-10-16T10:00:00Z")
        let rings = Self.market.rings(after: Self.now, within: ClockAlarm.window, device: Self.ist)
        var fixed = Dictionary(uniqueKeysWithValues: rings.enumerated().map { (Self.id($0.offset + 2), $0.element) })
        fixed[Self.id(1)] = past
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: Self.market.fingerprint, fixed: fixed)
        let step = Self.step(Self.market, scheduled, live: Set(fixed.keys))
        #expect(step.cancel.isEmpty && step.scheduleFixed.isEmpty)
    }

    @Test("One-off: armed for its next ring; turns off once that passed and the system dropped it")
    func oneOff() throws {
        let armed = AlarmTests.alarm(6, 0, zone: AlarmTests.ny, days: []).armed(now: Self.now, device: Self.ist)
        #expect(armed.onceAt == AlarmTests.utc("2026-10-17T10:00:00Z"))   // Sat 06:00 EDT
        let onceAt = try #require(armed.onceAt)
        let first = Self.step(armed)
        #expect(first.scheduleFixed == [onceAt])

        let after = AlarmTests.utc("2026-10-17T10:05:00Z")
        let scheduled = ClockAlarmPlan.Scheduled(fingerprint: armed.fingerprint, fixed: [Self.id(1): onceAt])
        // Still live: ringing or snoozed, so wait.
        #expect(!Self.step(armed, scheduled, live: [Self.id(1)], at: after).turnOff)
        let gone = Self.step(armed, scheduled, live: [], at: after)
        #expect(gone.turnOff)
        #expect(gone.scheduleFixed.isEmpty)
    }

    @Test("Armed one-offs never move to the next day")
    func onceStays() throws {
        let armed = AlarmTests.alarm(6, 0, zone: nil, days: []).armed(now: Self.now, device: Self.ist)
        let onceAt = try #require(armed.onceAt)
        #expect(armed.nextRing(after: Self.now, device: Self.ist) == onceAt)
        #expect(armed.nextRing(after: onceAt, device: Self.ist) == nil)
        #expect(armed.isSpent(at: onceAt))
    }
}

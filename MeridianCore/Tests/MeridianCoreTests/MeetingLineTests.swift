import Foundation
import Testing
@testable import MeridianCore

/// Decision AY (the Sessions meeting line) and BC (generic alarm reconcile).
@Suite("Meeting line and alarm diff")
struct MeetingLineTests {
    static let mumbai = PlannerZone(zone: Zone("Asia/Kolkata")!, name: "Mumbai")
    static let london = PlannerZone(zone: Zone("Europe/London")!, name: "London")
    static let sf = PlannerZone(zone: Zone("America/Los_Angeles")!, name: "SF")
    static let zones = [mumbai, london, sf]

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static func line(at iso: String, zones: [PlannerZone] = zones) -> MeetingLine? {
        MeetingLine.make(zones: zones, home: mumbai.zone, now: utc(iso))
    }

    // MARK: Meeting line

    @Test("Board: Best compromise in 21 min · 16:00 UTC (20 min 42 s rounds up)")
    func board() {
        let line = Self.line(at: "2026-10-15T15:39:18Z")
        #expect(line?.title == "Best compromise in 21 min")
        #expect(line?.detail == "16:00 UTC · 3 of 3 awake · Mumbai in stretch")
        // Board LiveActivity splits it the other way: time on the first line.
        #expect(line?.headline == "Best compromise in 21 min · 16:00 UTC")
        #expect(line?.counts == "3 of 3 awake · Mumbai in stretch")
        #expect(line?.start == Self.utc("2026-10-15T16:00:00Z"))
        #expect(line?.day == CivilDate(2026, 10, 15))
    }

    @Test("Hours and minutes; and 'now' when the window starts this minute")
    func wording() {
        #expect(Self.line(at: "2026-10-15T13:55:00Z")?.title == "Best compromise in 2 h 5 min")
        #expect(Self.line(at: "2026-10-15T14:00:00Z")?.title == "Best compromise in 2 h")
        #expect(Self.line(at: "2026-10-15T16:00:00Z")?.title == "Best compromise now")
    }

    @Test("All in work hours says Best time")
    func bestTime() {
        let line = MeetingLine.make(zones: [Self.mumbai, PlannerZone(zone: Zone("Asia/Singapore")!, name: "Singapore")],
                                    home: Self.mumbai.zone, now: Self.utc("2026-10-15T03:00:00Z"))
        #expect(line?.title == "Best time in 30 min")
        #expect(line?.detail == "03:30 UTC · 2 of 2 in work hours")
    }

    @Test("Saturday: no shared window today, next on Monday")
    func weekend() {
        let line = Self.line(at: "2026-10-17T06:00:00Z")
        #expect(line?.title == "No shared window today")
        #expect(line?.detail == "Next: Mon 16:00 UTC · 3 of 3 awake · Mumbai in stretch")
        #expect(line?.headline == "No shared window today · next Mon 16:00 UTC")
        #expect(line?.counts == "3 of 3 awake · Mumbai in stretch")
        #expect(line?.day == CivilDate(2026, 10, 19))
    }

    @Test("Hidden with fewer than 2 zones")
    func hidden() {
        #expect(Self.line(at: "2026-10-15T15:39:18Z", zones: [Self.mumbai]) == nil)
        #expect(Self.line(at: "2026-10-15T15:39:18Z", zones: []) == nil)
    }

    // MARK: Alarm diff

    static func id(_ n: Int) -> UUID { UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")! }
    static func t(_ minute: Int) -> Date { utc("2026-10-15T16:00:00Z").addingTimeInterval(TimeInterval(minute * 60)) }

    @Test("Everything in place: nothing to do")
    func diffClean() {
        let plan = AlarmDiff.plan(wanted: [Self.t(0), Self.t(5)], stored: [Self.id(1): Self.t(0), Self.id(2): Self.t(5)],
                                  live: [Self.id(1), Self.id(2)])
        #expect(plan.cancel.isEmpty)
        #expect(plan.schedule.isEmpty)
    }

    @Test("Moved boundaries: cancel the old, schedule the new, keep what still fits")
    func diffMoved() {
        // After +5 min: 0 → 5 and 5 → 10.
        let plan = AlarmDiff.plan(wanted: [Self.t(5), Self.t(10)], stored: [Self.id(1): Self.t(0), Self.id(2): Self.t(5)],
                                  live: [Self.id(1), Self.id(2)])
        #expect(plan.cancel == [Self.id(1)])
        #expect(plan.schedule == [Self.t(10)])
    }

    @Test("An alarm the system dropped is scheduled again; unknown stored ids are cancelled")
    func diffDropped() {
        let plan = AlarmDiff.plan(wanted: [Self.t(0), Self.t(5)], stored: [Self.id(1): Self.t(0), Self.id(2): Self.t(5),
                                                                           Self.id(3): Self.t(9)],
                                  live: [Self.id(1), Self.id(3)])
        #expect(plan.cancel == [Self.id(2), Self.id(3)])
        #expect(plan.schedule == [Self.t(5)])
    }

    @Test("Nothing wanted (stopped or paused): cancel all")
    func diffStop() {
        let plan = AlarmDiff.plan(wanted: [], stored: [Self.id(1): Self.t(0)], live: [Self.id(1)])
        #expect(plan.cancel == [Self.id(1)])
        #expect(plan.schedule.isEmpty)
    }
}

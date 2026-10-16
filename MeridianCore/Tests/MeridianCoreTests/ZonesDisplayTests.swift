import Foundation
import Testing
@testable import MeridianCore

/// M3 Core helpers for the Zones screens: Clocks day offsets and DST badges (spec §4.1,
/// decision K: offsets are relative to the home zone), DayPager text, the scrubber,
/// and the Planner day-length note. Expected values computed with Python zoneinfo.
@Suite("Zones display")
struct ZonesDisplayTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let ny = Zone("America/New_York")!
    static let sf = Zone("America/Los_Angeles")!
    static let tokyo = Zone("Asia/Tokyo")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    // MARK: Day offset (Clocks rows)

    @Test("Day offset relative to the home zone", arguments: [
        (london, ist, "2026-10-15T16:00:00Z", "Today · −4h 30m"),
        (sf, ist, "2026-10-15T16:00:00Z", "Today · −12h 30m"),
        (sf, ist, "2026-10-15T20:00:00Z", "Yesterday · −12h 30m"),   // Mumbai is already Friday
        (ist, sf, "2026-10-15T20:00:00Z", "Tomorrow · +12h 30m"),
        (tokyo, london, "2026-10-15T16:00:00Z", "Tomorrow · +8h"),
        (london, london, "2026-10-15T16:00:00Z", "Today · same time"),
    ])
    func dayOffset(zone: Zone, home: Zone, instant: String, text: String) {
        #expect(ZoneClock.dayOffsetText(zone, relativeTo: home, at: Self.utc(instant)) == text)
    }

    // MARK: DST badge (from 14 days before a change)

    @Test("DST badge for London's 25 Oct change", arguments: [
        ("2026-10-10T12:00:00Z", nil as String?),      // 15 days out: no badge yet
        ("2026-10-11T12:00:00Z", "DST in 14d"),
        ("2026-10-17T12:00:00Z", "DST in 8d"),
        ("2026-10-24T12:00:00Z", "DST tomorrow"),
        ("2026-10-25T00:30:00Z", "DST today"),         // 01:30 BST, half an hour before
        ("2026-10-25T02:00:00Z", nil),                 // after it; next change is March
    ])
    func dstBadge(now: String, text: String?) {
        #expect(ZoneClock.dstBadgeText(Self.london, now: Self.utc(now)) == text)
    }

    @Test("Zones without DST never get a badge")
    func noBadge() {
        #expect(ZoneClock.dstBadgeText(Self.ist, now: Self.utc("2026-10-17T12:00:00Z")) == nil)
        #expect(ZoneClock.dstBadgeText(.utc, now: Self.utc("2026-10-17T12:00:00Z")) == nil)
    }

    // MARK: DayPager

    static let planner = [
        PlannerZone(zone: ist, name: "Mumbai"), PlannerZone(zone: london, name: "London"), PlannerZone(zone: sf, name: "SF"),
    ]

    @Test("DayPager title, caption and label", arguments: [
        (CivilDate(2026, 10, 15), ist, "Thu 15 Oct", "W42 · day 288", "Today"),
        (CivilDate(2026, 10, 16), ist, "Fri 16 Oct", "W42 · day 289", "Tomorrow"),
        (CivilDate(2026, 10, 14), ist, "Wed 14 Oct", "W42 · day 287", "Yesterday"),
        (CivilDate(2026, 10, 19), ist, "Mon 19 Oct", "W43 · day 292", "In 4 days"),
        (CivilDate(2026, 10, 12), ist, "Mon 12 Oct", "W42 · day 285", "3 days ago"),
        (CivilDate(2026, 10, 17), ist, "Sat 17 Oct", "W42 · day 290", "Weekend"),
        (CivilDate(2026, 10, 25), london, "Sun 25 Oct", "W43 · day 298", "Clocks change in London"),  // beats Weekend
        (CivilDate(2026, 11, 1), london, "Sun 1 Nov", "W44 · day 305", "Clocks change in SF"),
    ])
    func pager(date: CivilDate, home: Zone, title: String, caption: String, label: String) {
        let pager = OverlapEngine.pager(for: date, today: CivilDate(2026, 10, 15), home: home, zones: Self.planner)
        #expect(pager.title == title)
        #expect(pager.caption == caption)
        #expect(pager.label == label)
    }

    @Test("Several zones changing on one day are all named")
    func pagerSeveralChanges() {
        let zones = [PlannerZone(zone: Self.london, name: "London"), PlannerZone(zone: Self.ny, name: "New York"),
                     PlannerZone(zone: Self.sf, name: "SF")]
        let pager = OverlapEngine.pager(for: CivilDate(2026, 11, 1), today: CivilDate(2026, 10, 15), home: Self.london,
                                        zones: zones)
        #expect(pager.label == "Clocks change in New York, SF")
    }

    @Test("Day length note on 23- and 25-hour days")
    func lengthNote() {
        #expect(OverlapEngine.day(CivilDate(2026, 10, 25), home: Self.london, zones: Self.planner).lengthNote == "25-hour day")
        #expect(OverlapEngine.day(CivilDate(2026, 3, 8), home: Self.ny, zones: Self.planner).lengthNote == "23-hour day")
        #expect(OverlapEngine.day(CivilDate(2026, 10, 15), home: Self.ist, zones: Self.planner).lengthNote == nil)
    }

    // MARK: Scrubber (15-minute snap, keeps wall time across days)

    static let londonLongDay = DateInterval(start: utc("2026-10-24T23:00:00Z"), end: utc("2026-10-26T00:00:00Z"))

    @Test("Fraction ↔ instant on a 25-hour axis, snapped and clamped", arguments: [
        (0.5, "2026-10-25T11:30:00Z"),              // half of 25 h, not 12:00
        (0.5013, "2026-10-25T11:30:00Z"),
        (0.0, "2026-10-24T23:00:00Z"),
        (-0.2, "2026-10-24T23:00:00Z"),
        (1.0, "2026-10-25T23:45:00Z"),              // last slot, not the axis end
        (1.4, "2026-10-25T23:45:00Z"),
    ])
    func fractionToInstant(fraction: Double, instant: String) {
        #expect(Scrubber.instant(atFraction: fraction, in: Self.londonLongDay) == Self.utc(instant))
    }

    @Test("Instant → fraction")
    func instantToFraction() {
        #expect(Scrubber.fraction(of: Self.utc("2026-10-25T11:30:00Z"), in: Self.londonLongDay) == 0.5)
    }

    @Test("Snap rounds to the nearest 15 minutes, halves up", arguments: [
        ("2026-10-25T11:37:00Z", "2026-10-25T11:30:00Z"),
        ("2026-10-25T11:37:30Z", "2026-10-25T11:45:00Z"),
        ("2026-10-25T11:52:29Z", "2026-10-25T11:45:00Z"),   // 7m29s past vs 7m31s before
    ])
    func snap(input: String, snapped: String) {
        #expect(Scrubber.snap(Self.utc(input), in: Self.londonLongDay) == Self.utc(snapped))
    }

    @Test("Steps of ±15 and ±30 minutes stay inside the axis", arguments: [
        ("2026-10-25T11:30:00Z", 15, "2026-10-25T11:45:00Z"),
        ("2026-10-25T11:30:00Z", -30, "2026-10-25T11:00:00Z"),
        ("2026-10-25T23:45:00Z", 15, "2026-10-25T23:45:00Z"),
        ("2026-10-24T23:00:00Z", -15, "2026-10-24T23:00:00Z"),
    ])
    func step(from: String, minutes: Int, to: String) {
        #expect(Scrubber.step(Self.utc(from), byMinutes: minutes, in: Self.londonLongDay) == Self.utc(to))
    }

    @Test("Changing day keeps the wall time; a skipped time moves to the next valid slot")
    func keepWallTime() {
        #expect(Scrubber.instant(keeping: ClockTime(9, 0), on: CivilDate(2026, 10, 16), in: Self.ny)
                == Self.utc("2026-10-16T13:00:00Z"))
        #expect(Scrubber.instant(keeping: ClockTime(2, 30), on: CivilDate(2026, 3, 8), in: Self.ny)
                == Self.utc("2026-03-08T07:00:00Z"))                                       // 03:00 EDT
        #expect(Scrubber.wallTime(of: Self.utc("2026-10-15T16:00:00Z"), in: Self.ist) == ClockTime(21, 30))
    }
}

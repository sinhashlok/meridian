import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § ZoneClock, § Gap / overlap rule and § Conversions used
/// across screens. Abbreviations follow decision B (docs/decisions.md).
@Suite("ZoneClock")
struct ZoneClockTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let ny = Zone("America/New_York")!
    static let sf = Zone("America/Los_Angeles")!

    /// `"2026-10-15T16:00:00Z"` → Date. Test helper only.
    static func utc(_ iso: String) -> Date {
        try! EpochParser.parseISO8601(iso).date
    }

    static func local(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> LocalDateTime {
        LocalDateTime(date: CivilDate(y, m, d), hour: h, minute: min)
    }

    // MARK: DST transitions 2026

    @Test("Transitions in 2026", arguments: [
        (london, "2026-03-29T01:00:00Z", "GMT (UTC+0)", "BST (UTC+1)", "06:30"),
        (london, "2026-10-25T01:00:00Z", "BST (UTC+1)", "GMT (UTC+0)", "06:30"),
        (ny, "2026-03-08T07:00:00Z", "EST (UTC−5)", "EDT (UTC−4)", "12:30"),
        (ny, "2026-11-01T06:00:00Z", "EDT (UTC−4)", "EST (UTC−5)", "11:30"),
        (sf, "2026-03-08T10:00:00Z", "PST (UTC−8)", "PDT (UTC−7)", "15:30"),
        (sf, "2026-11-01T09:00:00Z", "PDT (UTC−7)", "PST (UTC−8)", "14:30"),
    ])
    func transition(zone: Zone, instant: String, before: String, after: String, istTime: String) {
        let year = ZoneClock.transitions(in: zone, from: Self.utc("2026-01-01T00:00:00Z"),
                                         to: Self.utc("2027-01-01T00:00:00Z"))
        let match = year.first { $0.instant == Self.utc(instant) }
        #expect(year.count == 2)
        #expect(match?.before.label == before)
        #expect(match?.after.label == after)
        // Fixture's IST column (given for the autumn rows): the change seen from Mumbai.
        #expect(ZoneClock.wallTime(Self.utc(instant), in: Self.ist) == istTime)
    }

    @Test("Mumbai has no clock changes")
    func mumbaiNoChanges() {
        let year = ZoneClock.transitions(in: Self.ist, from: Self.utc("2026-01-01T00:00:00Z"),
                                         to: Self.utc("2027-01-01T00:00:00Z"))
        #expect(year.isEmpty)
    }

    @Test("Day lengths: 25 h, 23 h and a normal 24 h day")
    func dayLengths() {
        #expect(ZoneClock.dayLength(of: CivilDate(2026, 10, 25), in: Self.london) == 25 * 3600)
        #expect(ZoneClock.dayLength(of: CivilDate(2026, 3, 8), in: Self.ny) == 23 * 3600)
        #expect(ZoneClock.dayLength(of: CivilDate(2026, 10, 16), in: Self.ny) == 24 * 3600)
    }

    // MARK: Gap / overlap rule (spec §5.2)

    @Test("Repeated and skipped local times", arguments: [
        (ny, local(2026, 11, 1, 1, 30), Occurrence.first, "2026-11-01T05:30:00Z", Resolution.Kind.repeated),
        (ny, local(2026, 11, 1, 1, 30), .second, "2026-11-01T06:30:00Z", .repeated),
        (london, local(2026, 10, 25, 1, 30), .first, "2026-10-25T00:30:00Z", .repeated),
        (london, local(2026, 10, 25, 1, 30), .second, "2026-10-25T01:30:00Z", .repeated),
        // Policy: next valid time. Python zoneinfo gives 07:30Z here; we deliberately differ.
        (ny, local(2026, 3, 8, 2, 30), .first, "2026-03-08T07:00:00Z", .skipped),
        (ny, local(2026, 3, 8, 2, 30), .second, "2026-03-08T07:00:00Z", .skipped),
        (ny, local(2026, 10, 16, 9, 0), .first, "2026-10-16T13:00:00Z", .exact),
    ])
    func resolve(zone: Zone, time: LocalDateTime, occurrence: Occurrence, expected: String, kind: Resolution.Kind) {
        let result = ZoneClock.resolve(time, in: zone, occurrence: occurrence)
        #expect(result.instant == Self.utc(expected))
        #expect(result.kind == kind)
    }

    @Test("London 01:30 First is epoch 1792888200, 06:00 IST")
    func londonFirstEpoch() {
        let result = ZoneClock.resolve(Self.local(2026, 10, 25, 1, 30), in: Self.london, occurrence: .first)
        #expect(result.instant.timeIntervalSince1970 == 1_792_888_200)
        #expect(ZoneClock.wallTime(result.instant, in: Self.ist) == "06:00")
    }

    @Test("Skipped 02:30 lands on 03:00 EDT")
    func skippedLabel() {
        let result = ZoneClock.resolve(Self.local(2026, 3, 8, 2, 30), in: Self.ny, occurrence: .first)
        #expect(ZoneClock.copyText(result.instant, in: Self.ny) == "03:00 EDT (UTC−4)")
    }

    // MARK: Conversions used across screens

    @Test("Meeting copy text on 15 Oct (BST) and 26 Oct (GMT)", arguments: [
        ("2026-10-15T16:00:00Z", ["21:30 IST (UTC+5:30)", "17:00 BST (UTC+1)", "09:00 PDT (UTC−7)"]),
        ("2026-10-26T16:00:00Z", ["21:30 IST (UTC+5:30)", "16:00 GMT (UTC+0)", "09:00 PDT (UTC−7)"]),
    ])
    func meetingCopyText(instant: String, expected: [String]) {
        let texts = [Self.ist, Self.london, Self.sf].map { ZoneClock.copyText(Self.utc(instant), in: $0) }
        #expect(texts == expected)
    }

    @Test("Alarm 09:00 NY, Keep NY time: before and after 1 Nov", arguments: [
        (CivilDate(2026, 10, 16), "2026-10-16T13:00:00Z", "18:30"),
        (CivilDate(2026, 11, 2), "2026-11-02T14:00:00Z", "19:30"),
    ])
    func keepZoneTime(day: CivilDate, utc: String, ist: String) {
        let ring = ZoneClock.resolve(LocalDateTime(date: day, hour: 9, minute: 0), in: Self.ny, occurrence: .first)
        #expect(ring.instant == Self.utc(utc))
        #expect(ZoneClock.wallTime(ring.instant, in: Self.ist) == ist)
    }

    @Test("Same alarm, Keep UTC time: 13:00Z always; NY time becomes 08:00 after 1 Nov")
    func keepUTCTime() {
        let before = ZoneClock.resolve(Self.local(2026, 10, 16, 13, 0), in: .utc, occurrence: .first)
        let after = ZoneClock.resolve(Self.local(2026, 11, 2, 13, 0), in: .utc, occurrence: .first)
        #expect(ZoneClock.wallTime(before.instant, in: Self.ny) == "09:00")
        #expect(ZoneClock.wallTime(after.instant, in: Self.ny) == "08:00")
    }

    @Test("Monthly job day 1, 01:00 NY: first occurrence on 1 Nov, normal on 1 Dec")
    func monthlyJob() {
        let nov = ZoneClock.resolve(Self.local(2026, 11, 1, 1, 0), in: Self.ny, occurrence: .first)
        #expect(nov.instant == Self.utc("2026-11-01T05:00:00Z"))
        #expect(nov.kind == .repeated)
        #expect(ZoneClock.wallTime(nov.instant, in: Self.ist) == "10:30")
        let dec = ZoneClock.resolve(Self.local(2026, 12, 1, 1, 0), in: Self.ny, occurrence: .first)
        #expect(dec.instant == Self.utc("2026-12-01T06:00:00Z"))
        #expect(dec.kind == .exact)
    }

    @Test("Until 02:00 UTC from 15:39:18Z: 10:20:42 remaining, 07:30 IST Friday")
    func untilTimer() {
        let start = Self.utc("2026-10-15T15:39:18Z")
        // The Until timer's own resolver (TimerTests covers its gap/overlap cases).
        let target = UntilTarget.next(hour: 2, minute: 0, in: .utc, occurrence: .first, after: start).instant
        #expect(target.timeIntervalSince(start) == 10 * 3600 + 20 * 60 + 42)
        #expect(ZoneClock.wallTime(target, in: Self.ist) == "07:30")
        #expect(ZoneClock.local(target, in: Self.ist).date.isoWeekday == 5)    // Friday
    }

    // MARK: Labels (decision B)

    @Test("Offset labels use a real minus sign and minutes when needed", arguments: [
        (19_800, "UTC+5:30"), (-25_200, "UTC−7"), (0, "UTC+0"), (3600, "UTC+1"),
        (20_700, "UTC+5:45"), (-12_600, "UTC−3:30"), (50_400, "UTC+14"),
    ])
    func offsetLabels(seconds: Int, label: String) {
        #expect(ZoneClock.offsetLabel(seconds: seconds) == label)
    }

    @Test("UTC is written UTC; zones without a curated abbreviation show the offset only")
    func labels() {
        let instant = Self.utc("2026-10-15T16:00:00Z")
        #expect(ZoneClock.label(.utc, at: instant) == "UTC")
        #expect(ZoneClock.copyText(instant, in: .utc) == "16:00 UTC")
        #expect(ZoneClock.label(Zone("Asia/Kathmandu")!, at: instant) == "UTC+5:45")
        #expect(ZoneClock.copyText(instant, in: Zone("Asia/Kathmandu")!) == "21:45 UTC+5:45")
    }

    @Test("Unknown zone ids are rejected")
    func unknownZone() {
        #expect(Zone("Mars/Olympus_Mons") == nil)
        #expect(Zone("") == nil)
    }

    // MARK: CivilDate

    @Test("CivilDate arithmetic is whole days, never seconds")
    func civilDate() {
        let date = CivilDate(2026, 10, 25)
        #expect(date.adding(days: 1) == CivilDate(2026, 10, 26))
        #expect(CivilDate(2026, 12, 31).adding(days: 1) == CivilDate(2027, 1, 1))
        #expect(CivilDate(2028, 2, 28).adding(days: 1) == CivilDate(2028, 2, 29))
        #expect(CivilDate(2026, 3, 1).days(since: CivilDate(2026, 2, 1)) == 28)
        #expect(date.isoWeekday == 7)                          // Sunday
        #expect(CivilDate(iso: "2026-10-15") == CivilDate(2026, 10, 15))
        #expect(CivilDate(iso: "2026-02-30") == nil)
        #expect(CivilDate(2026, 10, 15) < CivilDate(2026, 10, 16))
    }
}

import Foundation
import Testing
@testable import MeridianCore

/// Planner wording from the design boards (Planner, PlannerScrub, PlannerDST,
/// PlannerLondon25h): the day banner, grid header, row captions, the DST fault line and
/// the 23/25-hour note, the scrub bubble and UTC meeting ranges (decision N).
/// Expected instants and offsets checked with Python zoneinfo.
@Suite("Planner text")
struct PlannerTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let ny = Zone("America/New_York")!
    static let sf = Zone("America/Los_Angeles")!
    static let tokyo = Zone("Asia/Tokyo")!
    static let kathmandu = Zone("Asia/Kathmandu")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static let mumbai = PlannerZone(zone: ist, name: "Mumbai")
    static let londonZone = PlannerZone(zone: london, name: "London")
    static let sanFrancisco = PlannerZone(zone: sf, name: "San Francisco")
    /// The boards' three cities, Mumbai first (home).
    static let boards = [mumbai, londonZone, sanFrancisco]

    static func day(_ date: CivilDate, home: Zone, _ zones: [PlannerZone] = boards) -> PlannerDay {
        OverlapEngine.day(date, home: home, zones: zones)
    }

    // MARK: Banner (the viewed day)

    @Test("No overlap names the pair whose working hours never meet")
    func bannerNoOverlap() {
        // Mumbai works 03:30–12:30 UTC, SF 16:00–01:00 UTC; London overlaps both.
        let banner = Self.day(CivilDate(2026, 10, 15), home: Self.ist).banner
        #expect(banner == PlannerBanner(title: "No hour works for all 3 cities",
                                        detail: "Mumbai and San Francisco working hours never meet."))
    }

    @Test("Weekend in every zone replaces the no-overlap banner")
    func bannerWeekend() {
        #expect(Self.day(CivilDate(2026, 10, 25), home: Self.ist).banner
                == PlannerBanner(title: "Weekend in all 3 cities", detail: nil))
    }

    @Test("A day with an all-work overlap has no banner")
    func bannerNone() {
        #expect(Self.day(CivilDate(2026, 10, 15), home: Self.ist, [Self.mumbai, Self.londonZone]).banner == nil)
    }

    @Test("A zone with no work hours that day is named as on its weekend")
    func bannerOneZoneWeekend() {
        // Work days Sun–Thu: Friday has no work hours there.
        let dubai = PlannerZone(zone: Zone("Asia/Dubai")!, name: "Dubai", workDays: [7, 1, 2, 3, 4])
        let banner = Self.day(CivilDate(2026, 10, 16), home: Self.london, [Self.londonZone, dubai]).banner
        #expect(banner == PlannerBanner(title: "No hour works for all 2 cities", detail: "Dubai is on its weekend."))
    }

    @Test("Pairs are judged on the home day only")
    func bannerHomeDayOnly() {
        // Home SF, Fri 16 Oct: SF works 16:00–01:00 UTC; Tokyo's Friday work (07:00–09:00 UTC)
        // is the only part on SF's day, so SF and Tokyo never meet.
        let tokyo = PlannerZone(zone: Self.tokyo, name: "Tokyo")
        let banner = Self.day(CivilDate(2026, 10, 16), home: Self.sf, [Self.sanFrancisco, tokyo]).banner
        #expect(banner?.detail == "San Francisco and Tokyo working hours never meet.")
    }

    // MARK: Grid header and row captions

    @Test("Grid header: reference abbreviation and day; the name when the reference changes clocks", arguments: [
        (CivilDate(2026, 10, 15), ist, "Mumbai", "IST · Thu 15"),
        (CivilDate(2026, 10, 25), london, "London", "London · Sun 25"),
        (CivilDate(2026, 10, 15), Zone.utc, "UTC", "UTC · Thu 15"),
        (CivilDate(2026, 10, 15), kathmandu, "Kathmandu", "UTC+5:45 · Thu 15"),
    ])
    func header(date: CivilDate, reference: Zone, name: String, text: String) {
        #expect(Self.day(date, home: reference).headerTitle(reference: reference, referenceName: name) == text)
    }

    @Test("Row captions show each zone's time now on a plain today")
    func captionsToday() {
        let day = Self.day(CivilDate(2026, 10, 15), home: Self.ist)
        let now = Self.utc("2026-10-15T15:32:07Z")
        #expect(day.rows.map { day.caption(for: $0.zone, now: now) } == ["21:02 IST", "16:32 BST", "08:32 PDT"])
    }

    @Test("Row captions show offsets on another day, and the change on a clock-change day")
    func captionsOtherDay() {
        let now = Self.utc("2026-10-15T15:32:07Z")
        let sunday = Self.day(CivilDate(2026, 10, 25), home: Self.ist)
        #expect(sunday.rows.map { sunday.caption(for: $0.zone, now: now) } == ["IST · +5:30", "BST → GMT", "PDT · −7"])
        // London's 25-hour day is "today" on the board, but offsets matter more that day.
        let longDay = Self.day(CivilDate(2026, 10, 25), home: Self.london)
        #expect(longDay.caption(for: Self.mumbai, now: Self.utc("2026-10-25T10:15:07Z")) == "IST · +5:30")
        let friday = Self.day(CivilDate(2026, 10, 16), home: Self.ist)
        let nepal = PlannerZone(zone: Self.kathmandu, name: "Kathmandu")
        #expect(friday.caption(for: nepal, now: now) == "UTC+5:45")
        #expect(friday.caption(for: PlannerZone(zone: .utc, name: "UTC"), now: now) == "UTC")
    }

    // MARK: Fault line (a non-reference zone changes clocks)

    @Test("Fault-line chip and note on Mumbai's Sun 25 Oct")
    func faultLineAutumn() {
        let day = Self.day(CivilDate(2026, 10, 25), home: Self.ist)
        #expect(day.faultLines(reference: Self.ist)
                == [FaultLine(zoneName: "London", instant: Self.utc("2026-10-25T01:00:00Z"), chip: "London −1h, Sun 25 Oct")])
        #expect(day.faultLineNote(reference: Self.ist, referenceName: "Mumbai") ==
                "At 01:00 UTC London goes from BST to GMT. Its day moves 1h later on this timeline: "
                + "London is now 5h 30m behind Mumbai, not 4h 30m. San Francisco follows on Sun 1 Nov.")
    }

    @Test("Fault line in spring: the day moves earlier")
    func faultLineSpring() {
        let day = Self.day(CivilDate(2027, 3, 28), home: Self.ist)
        #expect(day.faultLines(reference: Self.ist).map(\.chip) == ["London +1h, Sun 28 Mar"])
        #expect(day.faultLineNote(reference: Self.ist, referenceName: "Mumbai") ==
                "At 01:00 UTC London goes from GMT to BST. Its day moves 1h earlier on this timeline: "
                + "London is now 4h 30m behind Mumbai, not 5h 30m.")
    }

    @Test("Against UTC, a zone can move level with the reference")
    func faultLineLevel() {
        let day = Self.day(CivilDate(2026, 10, 25), home: .utc)
        #expect(day.faultLineNote(reference: .utc, referenceName: "UTC") ==
                "At 01:00 UTC London goes from BST to GMT. Its day moves 1h later on this timeline: "
                + "London is now level with UTC, not 1h ahead. San Francisco follows on Sun 1 Nov.")
    }

    @Test("The reference zone's own change is not a fault line")
    func noFaultLineForReference() {
        let day = Self.day(CivilDate(2026, 10, 25), home: Self.london)
        #expect(day.faultLines(reference: Self.london).isEmpty)
        #expect(day.faultLineNote(reference: Self.london, referenceName: "London") == nil)
        #expect(Self.day(CivilDate(2026, 10, 15), home: Self.ist).faultLineNote(reference: Self.ist,
                                                                               referenceName: "Mumbai") == nil)
    }

    // MARK: Reference zone changes clocks (23/25-hour axis)

    @Test("London's 25-hour day: repeated hour, its label and the note")
    func referenceFallBack() throws {
        let change = try #require(Self.day(CivilDate(2026, 10, 25), home: Self.london)
            .referenceChange(reference: Self.london, referenceName: "London"))
        #expect(change.instant == Self.utc("2026-10-25T01:00:00Z"))
        #expect(change.label == "01 BST · 01 GMT")
        #expect(change.repeated == DateInterval(start: Self.utc("2026-10-25T00:00:00Z"), end: Self.utc("2026-10-25T02:00:00Z")))
        #expect(change.note == "London clocks go back at 02:00 BST, so 01:00–02:00 happens twice. "
                + "The axis is 25 hours long, and every row is placed by real time.")
    }

    @Test("23-hour days: the skipped hour", arguments: [
        (CivilDate(2027, 3, 28), london, "London", "01–02 skipped",
         "London clocks go forward at 01:00 GMT, so 01:00–02:00 is skipped. "
         + "The axis is 23 hours long, and every row is placed by real time."),
        (CivilDate(2026, 3, 8), ny, "New York", "02–03 skipped",
         "New York clocks go forward at 02:00 EST, so 02:00–03:00 is skipped. "
         + "The axis is 23 hours long, and every row is placed by real time."),
    ])
    func referenceSpringForward(date: CivilDate, zone: Zone, name: String, label: String, note: String) throws {
        let change = try #require(Self.day(date, home: zone).referenceChange(reference: zone, referenceName: name))
        #expect(change.label == label)
        #expect(change.repeated == nil)
        #expect(change.note == note)
    }

    @Test("No reference change on a 24-hour day")
    func noReferenceChange() {
        #expect(Self.day(CivilDate(2026, 10, 25), home: Self.ist).referenceChange(reference: Self.ist,
                                                                                 referenceName: "Mumbai") == nil)
    }

    // MARK: Scrub bubble and UTC ranges

    @Test("Scrub bubble: day, time and abbreviation; UTC added while scrubbing", arguments: [
        ("2026-10-15T16:00:00Z", ist, false, "Thu 21:30 IST"),
        ("2026-10-15T15:00:00Z", ist, true, "Thu 20:30 IST · 15:00 UTC"),
        ("2026-10-15T15:00:00Z", Zone.utc, true, "Thu 15:00 UTC"),
        ("2026-10-15T15:30:00Z", kathmandu, false, "Thu 21:15 UTC+5:45"),
    ])
    func bubble(instant: String, reference: Zone, withUTC: Bool, text: String) {
        #expect(Scrubber.bubbleText(Self.utc(instant), reference: reference, withUTC: withUTC) == text)
    }

    @Test("Meeting range and summary in UTC")
    func utcRange() {
        let start = Self.utc("2026-10-15T16:00:00Z")
        #expect(MeetingText.utcRange(start: start, minutes: 30) == "16:00–16:30 UTC")
        #expect(MeetingText.utcRange(start: Self.utc("2026-10-26T16:00:00Z"), minutes: 30, showsDay: true)
                == "Mon 16:00–16:30 UTC")
        #expect(MeetingText.utcRange(start: Self.utc("2026-10-15T23:45:00Z"), minutes: 30) == "23:45–00:15 UTC")
        #expect(MeetingText.summary(start: start, minutes: 30) == "Thu 15 Oct · 30 min")
    }
}

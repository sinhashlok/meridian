import Foundation
import Testing
@testable import MeridianCore

/// Copy/Share text, spec §4.1 (the example block is the fixture), plus decision L tags
/// and the "changes clocks" note (spec §5.3 Share/copy).
@Suite("MeetingText")
struct MeetingTextTests {
    static let mumbai = PlannerZone(zone: Zone("Asia/Kolkata")!, name: "Mumbai")
    static let london = PlannerZone(zone: Zone("Europe/London")!, name: "London")
    static let sanFrancisco = PlannerZone(zone: Zone("America/Los_Angeles")!, name: "San Francisco")
    static let zones = [mumbai, london, sanFrancisco]

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    @Test("Spec §4.1 example, exactly")
    func specExample() {
        let text = MeetingText.make(start: Self.utc("2026-10-15T16:00:00Z"), minutes: 30, zones: Self.zones,
                                    now: Self.utc("2026-10-15T15:32:00Z"))
        #expect(text == """
        Meeting · Thu 15 Oct · 30 min
        16:00–16:30 UTC

        Mumbai         21:30 IST (UTC+5:30)  late
        London         17:00 BST (UTC+1)
        San Francisco  09:00 PDT (UTC−7)
        """)
    }

    @Test("A clock change between now and the meeting is noted")
    func crossingNote() {
        let text = MeetingText.make(start: Self.utc("2026-10-26T16:00:00Z"), minutes: 30, zones: Self.zones,
                                    now: Self.utc("2026-10-22T10:00:00Z"))
        #expect(text == """
        Meeting · Mon 26 Oct · 30 min
        16:00–16:30 UTC

        Mumbai         21:30 IST (UTC+5:30)  late
        London         16:00 GMT (UTC+0)
        San Francisco  09:00 PDT (UTC−7)

        London changes clocks on Sun 25 Oct
        """)
    }

    @Test("Tags: early, late, asleep, weekend (decision L)", arguments: [
        ("2026-10-15T14:00:00Z", ["late", nil, "early"]),           // 19:30 IST · 15:00 BST · 07:00 PDT
        ("2026-10-15T08:00:00Z", [nil, nil, "asleep"]),             // SF 01:00
        ("2026-10-17T10:00:00Z", ["weekend", "weekend", "asleep"]), // Saturday; SF 03:00
    ])
    func tags(start: String, expected: [String?]) {
        #expect(MeetingText.tags(start: Self.utc(start), minutes: 30, zones: Self.zones) == expected)
    }

    @Test("Columns align to the longest name and label")
    func alignment() {
        let text = MeetingText.make(start: Self.utc("2026-10-15T14:00:00Z"), minutes: 60, zones: Self.zones,
                                    now: Self.utc("2026-10-15T00:00:00Z"))
        #expect(text == """
        Meeting · Thu 15 Oct · 60 min
        14:00–15:00 UTC

        Mumbai         19:30 IST (UTC+5:30)  late
        London         15:00 BST (UTC+1)
        San Francisco  07:00 PDT (UTC−7)     early
        """)
    }
}

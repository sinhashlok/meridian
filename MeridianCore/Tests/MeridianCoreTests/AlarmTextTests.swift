import Foundation
import Testing
@testable import MeridianCore

/// Boards AlarmsList and AlarmEdit (phone in IST, Fri 16 Oct 2026 15:45:07 IST) and
/// decisions BE, BJ, BN.
@Suite("Alarm text")
struct AlarmTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let ny = Zone("America/New_York")!
    static let london = Zone("Europe/London")!
    static let weekdays: Set<Int> = [1, 2, 3, 4, 5]
    static let now = AlarmTests.boardNow

    static func alarm(_ hour: Int, _ minute: Int, zone: Zone?, policy: ClockAlarm.Policy = .keepZone,
                      days: Set<Int> = weekdays, label: String = "", isOn: Bool = true) -> ClockAlarm {
        ClockAlarm(time: ClockTime(hour, minute), zoneID: zone?.id, policy: policy, repeatDays: days,
                   label: label, snoozeMinutes: 9, isOn: isOn)
    }

    /// The four alarms on board AlarmsList, in board order.
    static let board = [
        alarm(9, 0, zone: ny, label: "NY market open prep"),
        alarm(2, 0, zone: .utc, label: "Nightly pipeline check"),
        alarm(7, 45, zone: nil, label: "Wake"),
        alarm(6, 0, zone: nil, days: [6], label: "Gym", isOn: false),
    ]

    @Test("AlarmsList rows")
    func rows() {
        let rows = Self.board.map { AlarmText.row($0, now: Self.now, device: Self.ist) }
        #expect(rows.map(\.time) == ["09:00", "02:00", "07:45", "06:00"])
        #expect(rows.map(\.zoneTag) == ["New York", "UTC", nil, nil])
        #expect(rows.map(\.phoneLine) == ["18:30 IST on this phone", "07:30 IST on this phone", nil, nil])
        #expect(rows.map(\.caption) == ["NY market open prep · Weekdays", "Nightly pipeline check · Weekdays",
                                        "Wake · Weekdays", "Gym · Sat"])
        #expect(rows.map(\.dstBadge) == ["DST 1 Nov", nil, nil, nil])
    }

    @Test("A zoned alarm in the phone's own zone has no phone line")
    func sameZone() {
        #expect(AlarmText.row(Self.alarm(7, 0, zone: Self.ist), now: Self.now, device: Self.ist).phoneLine == nil)
    }

    @Test("Sorted by next ring, off alarms last (board order)")
    func sorted() {
        let shuffled = [Self.board[3], Self.board[2], Self.board[1], Self.board[0]]
        #expect(AlarmText.sorted(shuffled, now: Self.now, device: Self.ist).map(\.label)
                == Self.board.map(\.label))
    }

    @Test("Header: soonest ring in the shown zone; weekday when not today; nil with nothing on")
    func header() {
        #expect(AlarmText.header(Self.board, now: Self.now, display: Self.ist, device: Self.ist)
                == "Next: 18:30 IST today")
        #expect(AlarmText.header(Self.board, now: Self.now, display: .utc, device: Self.ist)
                == "Next: 13:00 UTC today")
        #expect(AlarmText.header([Self.board[1]], now: Self.now, display: Self.ist, device: Self.ist)
                == "Next: Mon 07:30 IST")
        #expect(AlarmText.header([Self.board[3]], now: Self.now, display: Self.ist, device: Self.ist) == nil)
    }

    @Test("Repeat text", arguments: [
        (Set<Int>(), "Never"), (Set(1...7), "Every day"), ([1, 2, 3, 4, 5], "Weekdays"),
        ([6, 7], "Weekends"), ([1, 3], "Mon, Wed"), ([6], "Sat"),
    ] as [(Set<Int>, String)])
    func repeatText(days: Set<Int>, expected: String) {
        #expect(AlarmText.repeatText(days) == expected)
    }

    @Test("One-off caption is the label alone; no label reads Alarm")
    func captions() {
        #expect(AlarmText.row(Self.alarm(6, 0, zone: nil, days: [], label: "Flight"), now: Self.now,
                              device: Self.ist).caption == "Flight")
        #expect(AlarmText.row(Self.alarm(6, 0, zone: nil), now: Self.now, device: Self.ist).caption
                == "Alarm · Weekdays")
    }

    @Test("AlarmEdit: local equivalent under the zone row")
    func localEquivalent() {
        #expect(AlarmText.localEquivalent(Self.alarm(9, 0, zone: Self.ny), now: Self.now, device: Self.ist)
                == "18:30 IST on this phone today · EDT (UTC−4)")
        #expect(AlarmText.localEquivalent(Self.alarm(2, 0, zone: .utc), now: Self.now, device: Self.ist)
                == "07:30 IST on this phone Mon · UTC")
        #expect(AlarmText.localEquivalent(Self.alarm(7, 45, zone: nil), now: Self.now, device: Self.ist) == nil)
    }

    @Test("AlarmEdit: the two choices")
    func policyChoices() {
        let choices = AlarmText.policyChoices(Self.alarm(9, 0, zone: Self.ny), now: Self.now, device: Self.ist)
        #expect(choices?.keepZone == PolicyChoice(title: "Keep New York time", detail: "Always 09:00 in New York"))
        #expect(choices?.keepUTC == PolicyChoice(title: "Keep UTC time",
                                                 detail: "Always 13:00 UTC; New York time moves"))
    }

    @Test("The choice is hidden for Local and zones without clock changes", arguments: [
        ("America/New_York", true), ("UTC", false), ("Asia/Kolkata", false),
    ])
    func policyVisibility(zoneID: String, shown: Bool) {
        let alarm = Self.alarm(9, 0, zone: Zone(zoneID)!)
        #expect((AlarmText.policyChoices(alarm, now: Self.now, device: Self.ist) != nil) == shown)
        #expect(AlarmText.policyChoices(Self.alarm(9, 0, zone: nil), now: Self.now, device: Self.ist) == nil)
    }

    @Test("AlarmEdit DST note, Keep New York time")
    func dstNoteKeepZone() {
        #expect(AlarmText.dstNote(Self.alarm(9, 0, zone: Self.ny), now: Self.now, device: Self.ist)
                == "After 1 Nov this rings at 19:30 on this phone. Still 09:00 in New York (EST, UTC−5).")
    }

    @Test("DST note, Keep UTC time")
    func dstNoteKeepUTC() {
        let alarm = Self.alarm(9, 0, zone: Self.ny, policy: .keepUTC(ClockTime(13, 0)))
        #expect(AlarmText.dstNote(alarm, now: Self.now, device: Self.ist)
                == "After 1 Nov this rings at 08:00 in New York (EST, UTC−5). Still 18:30 on this phone.")
    }

    @Test("DST note when the phone's zone changes first (London phone)")
    func dstNotePhoneChanges() {
        #expect(AlarmText.dstNote(Self.alarm(9, 0, zone: Self.ny), now: Self.now, device: Self.london)
                == "After 25 Oct this rings at 13:00 on this phone. Still 09:00 in New York (EDT, UTC−4).")
        #expect(AlarmText.row(Self.alarm(9, 0, zone: Self.ny), now: Self.now, device: Self.london).dstBadge
                == "DST 25 Oct")
    }

    @Test("No DST note or badge when nothing moves")
    func noNote() {
        #expect(AlarmText.dstNote(Self.alarm(2, 0, zone: .utc), now: Self.now, device: Self.ist) == nil)
        #expect(AlarmText.dstNote(Self.alarm(9, 0, zone: nil), now: Self.now, device: Self.ny) == nil)
        // Off alarms carry no badge.
        #expect(AlarmText.row(Self.alarm(9, 0, zone: Self.ny, isOn: false), now: Self.now, device: Self.ist)
            .dstBadge == nil)
    }

    @Test("Alert title: the label, plus the zone time for zoned alarms")
    func alertTitle() {
        #expect(Self.board.map(AlarmText.alertTitle) == ["NY market open prep · 09:00 New York",
                                                         "Nightly pipeline check · 02:00 UTC", "Wake", "Gym"])
        #expect(AlarmText.alertTitle(Self.alarm(7, 0, zone: nil)) == "Alarm")
    }
}

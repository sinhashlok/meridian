import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § Conversions (alarm rows) and decisions BD/BE: when a
/// ClockAlarm rings. Expected instants were checked with Python zoneinfo.
@Suite("Clock alarms")
struct AlarmTests {
    static let ist = Zone("Asia/Kolkata")!
    static let ny = Zone("America/New_York")!
    static let tokyo = Zone("Asia/Tokyo")!
    static let weekdays: Set<Int> = [1, 2, 3, 4, 5]
    /// Board AlarmsList: Fri 16 Oct 2026, 15:45:07 IST.
    static let boardNow = utc("2026-10-16T10:15:07Z")

    static func utc(_ iso: String) -> Date {
        try! EpochParser.parseISO8601(iso).date
    }

    static func alarm(_ hour: Int, _ minute: Int, zone: Zone?, policy: ClockAlarm.Policy = .keepZone,
                      days: Set<Int> = weekdays) -> ClockAlarm {
        ClockAlarm(time: ClockTime(hour, minute), zoneID: zone?.id, policy: policy, repeatDays: days,
                   label: "", snoozeMinutes: 9, isOn: true)
    }

    @Test("09:00 New York, Keep NY time: 13:00Z on Fri 16 Oct, 14:00Z on Mon 2 Nov")
    func keepZoneAcrossFallBack() {
        let alarm = Self.alarm(9, 0, zone: Self.ny)
        #expect(alarm.nextRing(after: Self.boardNow, device: Self.ist) == Self.utc("2026-10-16T13:00:00Z"))
        let afterChange = alarm.nextRing(after: Self.utc("2026-10-31T12:00:00Z"), device: Self.ist)
        #expect(afterChange == Self.utc("2026-11-02T14:00:00Z"))
        #expect(afterChange.map { ZoneClock.wallTime($0, in: Self.ist) } == "19:30")
    }

    @Test("Keep UTC time: always 13:00Z; New York reads 08:00 after 1 Nov")
    func keepUTC() {
        let utcTime = ClockAlarm.utcTime(of: ClockTime(9, 0), in: Self.ny, at: Self.boardNow)
        #expect(utcTime == ClockTime(13, 0))
        let alarm = Self.alarm(9, 0, zone: Self.ny, policy: .keepUTC(utcTime))
        let ring = alarm.nextRing(after: Self.utc("2026-10-31T12:00:00Z"), device: Self.ist)
        #expect(ring == Self.utc("2026-11-02T13:00:00Z"))
        #expect(ring.map { ZoneClock.wallTime($0, in: Self.ny) } == "08:00")
    }

    @Test("Keep UTC time worked out after the change is 14:00 UTC")
    func keepUTCAfterChange() {
        #expect(ClockAlarm.utcTime(of: ClockTime(9, 0), in: Self.ny, at: Self.utc("2026-11-02T12:00:00Z"))
                == ClockTime(14, 0))
    }

    @Test("Repeat days are read in the alarm's zone, also for Keep UTC (Tokyo Mon 08:00 = Sun 23:00Z)")
    func keepUTCDaysInAlarmZone() {
        let alarm = Self.alarm(8, 0, zone: Self.tokyo, policy: .keepUTC(ClockTime(23, 0)))
        #expect(alarm.nextRing(after: Self.boardNow, device: Self.ist) == Self.utc("2026-10-18T23:00:00Z"))
    }

    @Test("A 14-day window of weekday rings: 10 from the board's now")
    func window() {
        let rings = Self.alarm(9, 0, zone: Self.ny).rings(after: Self.boardNow, within: ClockAlarm.window,
                                                          device: Self.ist)
        #expect(rings.count == 10)
        #expect(rings.first == Self.utc("2026-10-16T13:00:00Z"))
        #expect(rings.last == Self.utc("2026-10-29T13:00:00Z"))
    }

    @Test("Skipped time rings at the next valid time; repeated time rings once, first")
    func gapAndOverlap() {
        let everyDay = Set(1...7)
        let gap = Self.alarm(2, 30, zone: Self.ny, days: everyDay)
        #expect(gap.nextRing(after: Self.utc("2026-03-08T00:00:00Z"), device: Self.ist)
                == Self.utc("2026-03-08T07:00:00Z"))   // 03:00 EDT
        let repeated = Self.alarm(1, 30, zone: Self.ny, days: everyDay)
        let rings = repeated.rings(after: Self.utc("2026-11-01T00:00:00Z"), within: 2 * 86_400, device: Self.ist)
        #expect(rings == [Self.utc("2026-11-01T05:30:00Z"), Self.utc("2026-11-02T06:30:00Z")])
    }

    @Test("Local alarms follow the phone's zone")
    func local() {
        let alarm = Self.alarm(7, 45, zone: nil)
        #expect(alarm.isLocal)
        #expect(alarm.nextRing(after: Self.boardNow, device: Self.ist) == Self.utc("2026-10-19T02:15:00Z"))
    }

    @Test("No repeat days: rings once")
    func once() {
        let alarm = Self.alarm(6, 0, zone: nil, days: [])
        let rings = alarm.rings(after: Self.boardNow, within: ClockAlarm.window, device: Self.ist)
        #expect(rings == [Self.utc("2026-10-17T00:30:00Z")])
    }

    @Test("JSON round trip")
    func codable() throws {
        let alarm = Self.alarm(9, 0, zone: Self.ny, policy: .keepUTC(ClockTime(13, 0)))
        let decoded = try JSONDecoder().decode(ClockAlarm.self, from: JSONEncoder().encode(alarm))
        #expect(decoded == alarm)
    }

    @Test("Editing a Keep UTC alarm after the change shows 08:00 and saves 13:00 UTC again (no drift)")
    func editKeepUTC() {
        let november = Self.utc("2026-11-02T12:00:00Z")
        let alarm = Self.alarm(9, 0, zone: Self.ny, policy: .keepUTC(ClockTime(13, 0)))
        let editing = alarm.forEditing(now: november, device: Self.ist)
        #expect(editing.time == ClockTime(8, 0))
        #expect(editing.saving(keepsUTC: true, now: november, device: Self.ist).policy == .keepUTC(ClockTime(13, 0)))
        let switched = editing.saving(keepsUTC: false, now: november, device: Self.ist)
        #expect(switched.policy == .keepZone && switched.time == ClockTime(8, 0))
    }

    @Test("Keep UTC only where the choice is shown: Local and UTC alarms save Keep <zone>")
    func savingWithoutChoice() {
        #expect(Self.alarm(7, 0, zone: nil).saving(keepsUTC: true, now: Self.boardNow, device: Self.ist).policy
                == .keepZone)
        #expect(Self.alarm(2, 0, zone: .utc).saving(keepsUTC: true, now: Self.boardNow, device: Self.ist).policy
                == .keepZone)
    }
}

import Foundation

/// One row of the Alarms list (board AlarmsList, decision BN).
public struct AlarmRowText: Equatable, Sendable {
    /// `09:00`: the alarm's own wall time (for Keep UTC, the zone's time at the next ring).
    public let time: String
    /// `New York`, `UTC`; `nil` for Local alarms.
    public let zoneTag: String?
    /// `18:30 IST on this phone`; `nil` for Local alarms and the phone's own zone.
    public let phoneLine: String?
    /// `NY market open prep · Weekdays`.
    public let caption: String
    /// `DST 1 Nov` (decision BJ).
    public let dstBadge: String?
}

/// One "When clocks change" option in the edit sheet.
public struct PolicyChoice: Equatable, Sendable {
    public let title: String
    public let detail: String
}

/// Wording for Alarms (spec §4.2, boards AlarmsList and AlarmEdit).
public enum AlarmText {
    /// The edit sheet's choice and note look this far ahead.
    static let noteWindow: TimeInterval = 366 * 24 * 3600

    public static func row(_ alarm: ClockAlarm, now: Date, device: Zone) -> AlarmRowText {
        let zone = alarm.zone(device: device)
        let ring = alarm.nextRing(after: now, device: device)
        var time = alarm.time.text
        if case .keepUTC = alarm.policy, let ring { time = ZoneClock.wallTime(ring, in: zone) }

        var phoneLine: String?
        if !alarm.isLocal, !zone.isSame(as: device), let ring {
            phoneLine = ZoneClock.timeWithAbbreviation(ring, in: device) + " on this phone"
        }
        let badge = alarm.isOn ? change(for: alarm, now: now, within: ClockMove.badgeWindow, device: device) : nil
        return AlarmRowText(time: time, zoneTag: alarm.isLocal ? nil : ZoneCatalog.displayName(for: zone),
                            phoneLine: phoneLine, caption: caption(alarm),
                            dstBadge: badge.map { "DST " + $0.date.dayMonthText })
    }

    /// On alarms by next ring, then off alarms by time of day (board AlarmsList).
    public static func sorted(_ alarms: [ClockAlarm], now: Date, device: Zone) -> [ClockAlarm] {
        let on = alarms.filter(\.isOn)
            .map { ($0, $0.nextRing(after: now, device: device) ?? .distantFuture) }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
        let off = alarms.filter { !$0.isOn }.sorted { $0.time < $1.time }
        return on + off
    }

    /// `Next: 18:30 IST today`, `Next: Mon 07:30 IST`; `nil` when no alarm is on.
    public static func header(_ alarms: [ClockAlarm], now: Date, display: Zone, device: Zone) -> String? {
        guard let ring = alarms.filter(\.isOn).compactMap({ $0.nextRing(after: now, device: device) }).min()
        else { return nil }
        let time = ZoneClock.timeWithAbbreviation(ring, in: display)
        let date = ZoneClock.local(ring, in: display).date
        return date == ZoneClock.local(now, in: display).date ? "Next: \(time) today" : "Next: \(date.weekdayText) \(time)"
    }

    /// `Never`, `Every day`, `Weekdays`, `Weekends`, `Mon, Wed`.
    public static func repeatText(_ days: Set<Int>) -> String {
        switch days {
        case []: "Never"
        case Set(1...7): "Every day"
        case [1, 2, 3, 4, 5]: "Weekdays"
        case [6, 7]: "Weekends"
        default: days.sorted().map { weekdayNames[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// What AlarmKit shows when it rings: `NY market open prep · 09:00 New York`, `Wake`.
    public static func alertTitle(_ alarm: ClockAlarm) -> String {
        let label = alarm.label.isEmpty ? "Alarm" : alarm.label
        guard let zoneID = alarm.zoneID, let zone = Zone(zoneID) else { return label }
        return "\(label) · \(alarm.time.text) \(ZoneCatalog.displayName(for: zone))"
    }

    /// Under the edit sheet's zone row: `18:30 IST on this phone today · EDT (UTC−4)`.
    /// `nil` for Local alarms and the phone's own zone.
    public static func localEquivalent(_ alarm: ClockAlarm, now: Date, device: Zone) -> String? {
        let zone = alarm.zone(device: device)
        guard !alarm.isLocal, !zone.isSame(as: device), let ring = alarm.nextRing(after: now, device: device)
        else { return nil }
        let date = ZoneClock.local(ring, in: device).date
        let day = date == ZoneClock.local(now, in: device).date ? "today" : date.weekdayText
        return ZoneClock.timeWithAbbreviation(ring, in: device) + " on this phone \(day) · "
            + ZoneClock.label(zone, at: ring)
    }

    /// "When clocks change" options; `nil` (hidden) for Local alarms and zones with no
    /// clock change in the next year (spec §4.2).
    public static func policyChoices(_ alarm: ClockAlarm, now: Date,
                                     device: Zone) -> (keepZone: PolicyChoice, keepUTC: PolicyChoice)? {
        let zone = alarm.zone(device: device)
        guard alarm.offersUTCChoice(now: now, device: device) else { return nil }
        let city = ZoneCatalog.displayName(for: zone)
        let utc: ClockTime = if case .keepUTC(let stored) = alarm.policy { stored }
                             else { ClockAlarm.utcTime(of: alarm.time, in: zone, at: now) }
        return (PolicyChoice(title: "Keep \(city) time", detail: "Always \(alarm.time.text) in \(city)"),
                PolicyChoice(title: "Keep UTC time", detail: "Always \(utc.text) UTC; \(city) time moves"))
    }

    /// The DSTNote under the choice: what the next clock change does to this alarm.
    /// `nil` when no change in the next year moves it.
    public static func dstNote(_ alarm: ClockAlarm, now: Date, device: Zone) -> String? {
        guard let change = change(for: alarm, now: now, within: noteWindow, device: device) else { return nil }
        let zone = alarm.zone(device: device)
        let city = ZoneCatalog.displayName(for: zone)
        let label = commaLabel(zone, at: change.instant)
        let after = "After \(change.date.dayMonthText) this rings at"

        switch alarm.policy {
        case .keepZone:
            let phone = alarm.time.shifted(by: change.phoneAfter - change.zoneAfter)
            return "\(after) \(phone.text) on this phone. Still \(alarm.time.text) in \(city) (\(label))."
        case .keepUTC(let utc):
            let inZone = "\(utc.shifted(by: change.zoneAfter).text) in \(city) (\(label))"
            let onPhone = "\(utc.shifted(by: change.phoneAfter).text) on this phone"
            switch (change.zoneMoves, change.phoneMoves) {
            case (true, false): return "\(after) \(inZone). Still \(onPhone)."
            case (false, true): return "\(after) \(onPhone). Still \(inZone)."
            default: return zone.isSame(as: device) ? "\(after) \(inZone)." : "\(after) \(inZone) and \(onPhone)."
            }
        }
    }

    // MARK: Private

    static let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// `EST, UTC−5` (board AlarmEdit's note, inside brackets); `UTC+4`; `UTC`.
    private static func commaLabel(_ zone: Zone, at instant: Date) -> String {
        let state = ZoneClock.state(zone, at: instant)
        guard !zone.isUTC, let abbreviation = state.abbreviation else { return state.label }
        return "\(abbreviation), \(ZoneClock.offsetLabel(seconds: state.offsetSeconds))"
    }

    private static func caption(_ alarm: ClockAlarm) -> String {
        let label = alarm.label.isEmpty ? "Alarm" : alarm.label
        return alarm.repeatDays.isEmpty ? label : "\(label) · \(repeatText(alarm.repeatDays))"
    }

    /// The first clock change within `within` that moves this alarm (Local alarms never move).
    private static func change(for alarm: ClockAlarm, now: Date, within: TimeInterval, device: Zone) -> ClockMove? {
        guard !alarm.isLocal else { return nil }
        let pinned: ClockMove.Pinned = if case .keepUTC = alarm.policy { .utcTime } else { .zoneTime }
        return ClockMove.first(zone: alarm.zone(device: device), device: device, pinned: pinned, now: now,
                               within: within)
    }
}

extension ClockTime {
    /// This time of day moved by `seconds` (an offset), wrapping round midnight.
    func shifted(by seconds: Int) -> ClockTime {
        let minutes = ((minutesAfterMidnight + seconds / 60) % 1440 + 1440) % 1440
        return ClockTime(minutesAfterMidnight: minutes)
    }
}

import Foundation
import MeridianCore
import SwiftData

/// A saved alarm (spec §7 `Alarm`, decision BO): the Core `ClockAlarm` as JSON, like
/// `SavedTimer`, plus what was scheduled with AlarmKit for it.
@Model
final class SavedAlarm {
    var data: Data
    /// `ClockAlarmPlan.Scheduled` as JSON: AlarmKit ids and their ring instants.
    var scheduledData: Data
    /// Creation order; the list itself is sorted by `AlarmText.sorted`.
    var order: Int

    init(alarm: ClockAlarm, order: Int) {
        self.data = (try? JSONEncoder().encode(alarm)) ?? Data()
        self.scheduledData = (try? JSONEncoder().encode(ClockAlarmPlan.Scheduled.none)) ?? Data()
        self.order = order
    }

    /// `nil` only if the stored JSON no longer decodes.
    var alarm: ClockAlarm? {
        get { try? JSONDecoder().decode(ClockAlarm.self, from: data) }
        set { if let newValue, let encoded = try? JSONEncoder().encode(newValue) { data = encoded } }
    }

    /// JSON keeps `Date` as seconds since 2001, which round-trips exactly (decision BC).
    var scheduled: ClockAlarmPlan.Scheduled {
        get { (try? JSONDecoder().decode(ClockAlarmPlan.Scheduled.self, from: scheduledData)) ?? .none }
        set { if let encoded = try? JSONEncoder().encode(newValue) { scheduledData = encoded } }
    }
}

/// Every change to saved alarms goes through here: each save re-arms one-off alarms
/// (decision BF) and the caller then runs `ClockAlarms.shared.sync`.
enum AlarmStore {
    /// Decoded alarms, rows kept alongside so rows can change them.
    static func alarms(from saved: [SavedAlarm]) -> [(row: SavedAlarm, alarm: ClockAlarm)] {
        saved.compactMap { row in row.alarm.map { (row, $0) } }
    }

    static func add(_ alarm: ClockAlarm, to saved: [SavedAlarm], in context: ModelContext) {
        context.insert(SavedAlarm(alarm: alarm.armed(now: .now, device: .device),
                                  order: (saved.map(\.order).max() ?? -1) + 1))
    }

    /// Applies a change (edit, switch on or off) to one row and re-arms it.
    static func update(_ row: SavedAlarm, _ change: (inout ClockAlarm) -> Void) {
        guard var alarm = row.alarm else { return }
        change(&alarm)
        row.alarm = alarm.armed(now: .now, device: .device)
    }

    /// The sync cancels its AlarmKit alarms: their ids are no longer claimed by any row.
    static func delete(_ row: SavedAlarm, in context: ModelContext) {
        context.delete(row)
    }

    /// `-MeridianAlarms demo`: board AlarmsList's four alarms; `none`: no alarms.
    /// Each replaces any saved alarms.
    static func applyDebugLaunch(_ saved: [SavedAlarm], in context: ModelContext) {
        guard let mode = DebugLaunch.alarms, ["demo", "none"].contains(mode) else { return }
        for row in saved { context.delete(row) }
        guard mode == "demo" else { return }
        let weekdays: Set<Int> = [1, 2, 3, 4, 5]
        let alarms = [
            ClockAlarm(time: ClockTime(9, 0), zoneID: "America/New_York", policy: .keepZone, repeatDays: weekdays,
                       label: "NY market open prep", snoozeMinutes: 9, isOn: true),
            ClockAlarm(time: ClockTime(2, 0), zoneID: "UTC", policy: .keepZone, repeatDays: weekdays,
                       label: "Nightly pipeline check", snoozeMinutes: 9, isOn: true),
            ClockAlarm(time: ClockTime(7, 45), zoneID: nil, policy: .keepZone, repeatDays: weekdays, label: "Wake",
                       snoozeMinutes: 9, isOn: true),
            ClockAlarm(time: ClockTime(6, 0), zoneID: nil, policy: .keepZone, repeatDays: [6], label: "Gym",
                       snoozeMinutes: 9, isOn: false),
        ]
        for (index, alarm) in alarms.enumerated() {
            context.insert(SavedAlarm(alarm: alarm, order: index))
        }
    }
}

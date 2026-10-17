import Foundation
import MeridianCore
import Observation
import SwiftData

/// Makes AlarmKit's alarms match the saved alarms (decisions BD, BF).
///
/// Local alarms are one relative alarm each; zoned alarms are fixed rings for the next
/// 14 days, refilled here. `sync` runs after every change, on launch and whenever the app
/// becomes active, because AlarmKit's update stream can't be trusted while suspended
/// (M0.5 test 9). Core's `ClockAlarmPlan` decides; this only talks to the system.
@MainActor @Observable final class ClockAlarms {
    static let shared = ClockAlarms()

    /// Alarms permission denied: alarms can't ring (banner on the Alarms list).
    private(set) var alarmsDenied = false

    /// One sync at a time, so quick toggles can't schedule twice.
    @ObservationIgnored private var running: Task<Void, Never>?

    /// Every AlarmKit id scheduled for alarms. Timers and sessions share AlarmKit's list,
    /// so this only ever cancels its own ids; an id no row claims (a deleted alarm) goes.
    private var knownIDs: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: "alarm.alarmIDs") ?? []).compactMap(UUID.init)) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: "alarm.alarmIDs") }
    }

    private init() {}

    /// Queues a reconcile of every saved alarm; await the task to know it's done.
    @discardableResult
    func sync(in context: ModelContext) -> Task<Void, Never> {
        let previous = running
        let task = Task {
            await previous?.value
            await reconcile(in: context)
        }
        running = task
        return task
    }

    // MARK: Private

    private func reconcile(in context: ModelContext) async {
        // Re-fetch: rows captured earlier may have been deleted since.
        guard let rows = try? context.fetch(FetchDescriptor<SavedAlarm>()) else { return }
        // The real clock and zone: alarms ring in the real world even when debug freezes the UI's.
        let now = Date.now
        let device = Zone.device

        // Asked when the first alarm is switched on, not at launch (spec §2).
        alarmsDenied = await AlarmService.alarmsDenied(askingIf: rows.contains { $0.alarm?.isOn == true })
        guard AlarmService.alarmsAuthorized else { return }

        let live = AlarmService.liveAlarmIDs
        var known = knownIDs
        let claimed = rows.reduce(into: Set<UUID>()) { $0.formUnion($1.scheduled.allIDs) }
        for id in known.subtracting(claimed) {
            AlarmService.cancelAlarm(id: id)
            known.remove(id)
        }

        for row in rows {
            guard var alarm = row.alarm else { continue }
            let step = ClockAlarmPlan.step(for: alarm, scheduled: row.scheduled, live: live, now: now, device: device)
            for id in step.cancel {
                AlarmService.cancelAlarm(id: id)
                known.remove(id)
            }
            if step.turnOff {
                alarm.isOn = false
                row.alarm = alarm
            }

            var kept = step.kept
            let title = AlarmText.alertTitle(alarm)
            // Awaited inside the serial sync, so the next sync already sees these. A refused
            // one isn't recorded, so the next sync tries again.
            for date in step.scheduleFixed {
                let id = UUID()
                if await AlarmService.scheduleAlarm(id: id, at: date, title: title, snoozeMinutes: alarm.snoozeMinutes) {
                    kept.fixed[id] = date
                    known.insert(id)
                }
            }
            if step.scheduleRelative {
                let id = UUID()
                if await AlarmService.scheduleRelativeAlarm(id: id, hour: alarm.time.hour, minute: alarm.time.minute,
                                                            weekdays: alarm.repeatDays, title: title,
                                                            snoozeMinutes: alarm.snoozeMinutes) {
                    kept.relative = id
                    known.insert(id)
                }
            }
            row.scheduled = kept
        }
        knownIDs = known
        try? context.save()
    }
}

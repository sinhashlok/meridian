import Foundation
import MeridianCore
import Observation
import SwiftData

/// Makes the system alarms match the saved timers (decisions AH, AI, AR).
///
/// Each running timer has one AlarmKit alarm at its end instant (`.fixed`), so it rings
/// through lock, Silent and Focus (M0.5). Pause, +1 min and resume schedule a new one.
/// If Alarms permission is denied, a local notification stands in (decision AI).
/// `sync` runs after every change, on launch and whenever the app becomes active,
/// because AlarmKit's update stream can't be trusted while suspended (M0.5 test 9).
@MainActor @Observable final class TimerAlarms {
    static let shared = TimerAlarms()

    /// Alarms permission denied: timers fall back to notifications.
    private(set) var alarmsDenied = false
    /// Notifications denied too: timers won't alert at all.
    private(set) var notificationsDenied = false

    /// One sync at a time, so two quick taps can't schedule two alarms.
    @ObservationIgnored private var running: Task<Void, Never>?

    /// Alarm ids we scheduled for timers. AlarmKit's list doesn't say what an alarm is
    /// for, and M7's wake-up alarms will share it, so reconcile only touches these.
    private var knownIDs: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: "timer.alarmIDs") ?? []).compactMap(UUID.init)) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: "timer.alarmIDs") }
    }

    private init() {}

    /// Queues a reconcile of every saved timer against the system's alarms; await the
    /// task to know the alarms and activity are done.
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
        guard let rows = try? context.fetch(FetchDescriptor<SavedTimer>()) else { return }
        // The real clock: alarms ring in the real world even when debug freezes the UI's.
        let now = Date.now
        let entries = rows.compactMap { row in row.timer.map { TimerAlarmPlan.Entry(timer: $0, alarmID: row.alarmID) } }
        let needsAlert = entries.contains { $0.timer.status(at: now) == .running }

        // Asked on the first Start, not at launch (spec §2).
        alarmsDenied = await AlarmService.alarmsDenied(askingIf: needsAlert)

        if alarmsDenied {
            await reconcileNotifications(rows: rows, entries: entries, now: now, needsAlert: needsAlert)
        } else {
            await reconcileAlarms(rows: rows, entries: entries, now: now)
            await AlarmService.removeNotifications(prefix: Self.prefix)
        }
        try? context.save()
        await TimerActivityController.update(entries.map(\.timer), now: now)
    }

    private func reconcileAlarms(rows: [SavedTimer], entries: [TimerAlarmPlan.Entry], now: Date) async {
        guard AlarmService.alarmsAuthorized else { return }
        var known = knownIDs.intersection(AlarmService.liveAlarmIDs)
        let plan = TimerAlarmPlan.reconcile(entries, scheduled: known, now: now)

        for id in plan.cancel {
            AlarmService.cancelAlarm(id: id)
            known.remove(id)
        }
        for row in rows where row.timer.map({ plan.clear.contains($0.id) }) ?? false {
            row.alarmID = nil
        }
        for row in rows {
            guard let timer = row.timer, plan.schedule.contains(timer.id), let end = timer.endDate else { continue }
            let id = UUID()
            row.alarmID = id
            known.insert(id)
            // Awaited inside the serial sync, so the next sync already sees this alarm. If it
            // fails, alarmID stays set; the next sync sees it missing and tries again.
            await AlarmService.scheduleAlarm(id: id, at: end, title: title(for: timer))
        }
        knownIDs = known
    }

    /// Decision AI: Alarms denied, so a notification at the end instead (quiet in Silent).
    private func reconcileNotifications(rows: [SavedTimer], entries: [TimerAlarmPlan.Entry], now: Date,
                                        needsAlert: Bool) async {
        notificationsDenied = await AlarmService.notificationsDenied(askingIf: needsAlert)
        let pending = await AlarmService.pendingNotificationIDs(prefix: Self.prefix)
        let plan = TimerAlarmPlan.reconcile(entries, scheduled: pending, now: now)
        await AlarmService.removeNotifications(prefix: Self.prefix, ids: plan.cancel)
        for row in rows {
            guard let timer = row.timer else { continue }
            if plan.clear.contains(timer.id) { row.alarmID = nil }
            guard plan.schedule.contains(timer.id), let end = timer.endDate, end > now else { continue }
            let id = UUID()
            row.alarmID = id
            await AlarmService.scheduleNotification(id: id, prefix: Self.prefix, at: end, title: title(for: timer),
                                                    body: timer.isDuration ? "Timer done" : "Until time reached",
                                                    now: now)
        }
    }

    private func title(for timer: CountdownTimer) -> String {
        TimerText.card(timer, now: .now, display: .device, displayIsPhone: true).title
    }

    /// Fallback notifications are `timer-<uuid>`.
    private static let prefix = "timer"
}

import AlarmKit
import Foundation
import MeridianCore
import Observation
import SwiftData
import SwiftUI  // Color.accent for the alarm tint
import UserNotifications

/// AlarmKit requires a metadata type even when there is nothing to attach.
/// `nonisolated` keeps it off the MainActor so it can be `Sendable`, as AlarmKit requires.
nonisolated struct TimerAlarmMetadata: AlarmMetadata {}

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
    @ObservationIgnored private var knownIDs: Set<UUID> {
        get { Set((UserDefaults.standard.stringArray(forKey: "timer.alarmIDs") ?? []).compactMap(UUID.init)) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: "timer.alarmIDs") }
    }

    private init() {}

    /// Queues a reconcile of every saved timer against the system's alarms.
    func sync(in context: ModelContext) {
        let previous = running
        running = Task {
            await previous?.value
            await reconcile(in: context)
        }
    }

    // MARK: Private

    private func reconcile(in context: ModelContext) async {
        // Re-fetch: rows captured earlier may have been deleted since.
        guard let rows = try? context.fetch(FetchDescriptor<SavedTimer>()) else { return }
        // The real clock: alarms ring in the real world even when debug freezes the UI's.
        let now = Date.now
        let entries = rows.compactMap { row in row.timer.map { TimerAlarmPlan.Entry(timer: $0, alarmID: row.alarmID) } }
        let needsAlert = entries.contains { $0.timer.status(at: now) == .running }

        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined, needsAlert {
            // Asked on the first Start, not at launch (spec §2).
            _ = try? await manager.requestAuthorization()
        }
        alarmsDenied = manager.authorizationState == .denied

        if alarmsDenied {
            await reconcileNotifications(rows: rows, entries: entries, now: now, needsAlert: needsAlert)
        } else {
            await reconcileAlarms(rows: rows, entries: entries, now: now)
            await removeTimerNotifications()
        }
        try? context.save()
        await TimerActivityController.update(entries.map(\.timer), now: now)
    }

    private func reconcileAlarms(rows: [SavedTimer], entries: [TimerAlarmPlan.Entry], now: Date) async {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }
        let systemIDs = Set((try? manager.alarms)?.map(\.id) ?? [])
        var known = knownIDs.intersection(systemIDs)
        let plan = TimerAlarmPlan.reconcile(entries, scheduled: known, now: now)

        for id in plan.cancel {
            try? manager.cancel(id: id)
            known.remove(id)
        }
        for row in rows where row.timer.map({ plan.clear.contains($0.id) }) ?? false {
            row.alarmID = nil
        }
        for row in rows {
            guard let timer = row.timer, plan.schedule.contains(timer.id), let end = timer.endDate else { continue }
            let id = Alarm.ID()
            row.alarmID = id
            known.insert(id)
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(end),
                attributes: AlarmAttributes<TimerAlarmMetadata>(presentation: AlarmPresentation(alert: alert(for: timer)),
                                                               tintColor: .accent))
            // Awaited inside the serial sync, so the next sync already sees this alarm.
            do {
                _ = try await manager.schedule(id: id, configuration: configuration)
            } catch {
                // Leave alarmID set; the next sync sees it missing and tries again.
                print("Timer alarm not scheduled: \(error)")
            }
        }
        knownIDs = known
    }

    /// Decision AI: Alarms denied, so a notification at the end instead (quiet in Silent).
    private func reconcileNotifications(rows: [SavedTimer], entries: [TimerAlarmPlan.Entry], now: Date,
                                        needsAlert: Bool) async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined, needsAlert {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        notificationsDenied = settings.authorizationStatus == .denied

        let pending = Set(await center.pendingNotificationRequests().compactMap { Self.uuid(from: $0.identifier) })
        let plan = TimerAlarmPlan.reconcile(entries, scheduled: pending, now: now)
        center.removePendingNotificationRequests(withIdentifiers: plan.cancel.map(Self.identifier))
        for row in rows {
            guard let timer = row.timer else { continue }
            if plan.clear.contains(timer.id) { row.alarmID = nil }
            guard plan.schedule.contains(timer.id), let end = timer.endDate, end > now else { continue }
            let id = UUID()
            row.alarmID = id
            let content = UNMutableNotificationContent()
            content.title = title(for: timer)
            content.body = timer.isDuration ? "Timer done" : "Until time reached"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSince(now), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.identifier(id), content: content, trigger: trigger))
        }
    }

    /// With Alarms allowed again, drop any fallback notifications so nothing alerts twice.
    private func removeTimerNotifications() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("timer-") }
        if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
    }

    private func title(for timer: CountdownTimer) -> String {
        TimerText.card(timer, now: .now, display: .device, displayIsPhone: true).title
    }

    /// From iOS 26.1 the system draws the Stop button itself and `stopButton` is deprecated.
    private func alert(for timer: CountdownTimer) -> AlarmPresentation.Alert {
        let title = LocalizedStringResource(stringLiteral: title(for: timer))
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title)
        } else {
            return AlarmPresentation.Alert(
                title: title,
                stopButton: AlarmButton(text: "Stop", textColor: .accent, systemImageName: "stop.circle"))
        }
    }

    private static func identifier(_ id: UUID) -> String { "timer-" + id.uuidString }

    private static func uuid(from identifier: String) -> UUID? {
        identifier.hasPrefix("timer-") ? UUID(uuidString: String(identifier.dropFirst(6))) : nil
    }
}

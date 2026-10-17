import Foundation
import MeridianCore
import Observation
import SwiftData

/// Keeps job reminders as local notifications in a rolling 48-hour window (decision BK).
/// Core's `ReminderPlan` decides; identifiers are `job-<id>-<run epoch>`, so the sync
/// diffs the pending ones with what's wanted. Runs after every job change, on launch and
/// whenever the app becomes active (and on background refresh, step 9).
@MainActor @Observable final class JobReminders {
    static let shared = JobReminders()

    /// Notifications denied: the Jobs list says reminders won't arrive.
    private(set) var notificationsDenied = DebugLaunch.notificationsOff

    @ObservationIgnored private var running: Task<Void, Never>?

    private init() {}

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

    /// Turn on: ask if never asked; otherwise the caller opens Settings. `true` if allowed.
    func requestPermission(in context: ModelContext) async -> Bool {
        let denied = await AlarmService.notificationsDenied(askingIf: true)
        notificationsDenied = denied
        if !denied { await sync(in: context).value }
        return !denied
    }

    private func reconcile(in context: ModelContext) async {
        guard let rows = try? context.fetch(FetchDescriptor<SavedJob>()) else { return }
        // The real clock: reminders arrive in the real world even when debug freezes the UI's.
        let now = Date.now
        let jobs = rows.compactMap(\.job)
        let wanted = ReminderPlan.wanted(jobs, now: now, device: .device)

        // Asked when the first reminder is turned on, not at launch (spec §2). Debug demo
        // launches (and `-MeridianNotif off`) don't ask, so the system prompt never covers a
        // screenshot.
        let asks = !wanted.isEmpty && DebugLaunch.jobs == nil && !DebugLaunch.notificationsOff
        let denied = await AlarmService.notificationsDenied(askingIf: asks)
        notificationsDenied = denied || DebugLaunch.notificationsOff
        guard !denied else { return }

        let pending = await AlarmService.pendingNotificationIdentifiers(prefix: ReminderPlan.prefix)
        let plan = ReminderPlan.diff(wanted: wanted, pending: pending)
        AlarmService.removeNotifications(identifiers: plan.remove)
        for reminder in plan.add {
            await AlarmService.scheduleNotification(identifier: reminder.identifier, at: reminder.fireDate,
                                                    title: reminder.title, body: reminder.body, now: now)
        }
    }
}

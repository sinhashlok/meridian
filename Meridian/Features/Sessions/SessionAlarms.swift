import Foundation
import MeridianCore
import Observation

/// Rings each phase change of the active session (decision AV): one AlarmKit alarm per
/// boundary still ahead, all scheduled up front so they ring with the app killed.
/// Reconciled with Core's `AlarmDiff` after every change, on launch and whenever the app
/// becomes active. Denied Alarms permission falls back to notifications (decision AI).
@MainActor @Observable final class SessionAlarms {
    static let shared = SessionAlarms()

    private(set) var alarmsDenied = false
    private(set) var notificationsDenied = false

    /// One sync at a time, so quick taps can't schedule twice; a burst of taps shares
    /// one follow-up sync.
    @ObservationIgnored private let queue = SyncQueue()

    /// Alarm (or fallback notification) id → fire date, for this session only.
    /// Dates are kept as seconds since 2001 (`Date`'s own reference), which round-trips
    /// exactly; seconds since 1970 doesn't, and `AlarmDiff` matches dates exactly.
    private var stored: [UUID: Date] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: "session.alarms") as? [String: Double] ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in
                UUID(uuidString: key).map { ($0, Date(timeIntervalSinceReferenceDate: value)) }
            })
        }
        set {
            UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: newValue.map {
                ($0.key.uuidString, $0.value.timeIntervalSinceReferenceDate)
            }), forKey: "session.alarms")
        }
    }

    private init() {}

    /// Queues a reconcile; await the task to know the alarms and activity are done.
    @discardableResult
    func sync() -> Task<Void, Never> {
        queue.enqueue { await self.reconcile() }
    }

    private func reconcile() async {
        // The real clock: alarms ring in the real world even when debug freezes the UI's.
        let now = Date.now
        let session = SessionStore.session
        let wanted = session?.upcomingAlarms(at: now) ?? []
        let titles = Dictionary(wanted.map { ($0.fireDate, $0.title) }, uniquingKeysWith: { first, _ in first })
        var map = stored

        alarmsDenied = await AlarmService.alarmsDenied(askingIf: !wanted.isEmpty)
        if alarmsDenied {
            notificationsDenied = await AlarmService.notificationsDenied(askingIf: !wanted.isEmpty)
            let live = await AlarmService.pendingNotificationIDs(prefix: Self.prefix)
            let plan = AlarmDiff.plan(wanted: Array(titles.keys), stored: map, live: live)
            await AlarmService.removeNotifications(prefix: Self.prefix, ids: plan.cancel)
            for id in plan.cancel { map[id] = nil }
            for date in plan.schedule {
                let id = UUID()
                map[id] = date
                await AlarmService.scheduleNotification(id: id, prefix: Self.prefix, at: date, title: titles[date] ?? "",
                                                        body: "Meridian session", now: now)
            }
        } else if AlarmService.alarmsAuthorized {
            let plan = AlarmDiff.plan(wanted: Array(titles.keys), stored: map, live: AlarmService.liveAlarmIDs)
            for id in plan.cancel {
                AlarmService.cancelAlarm(id: id)
                map[id] = nil
            }
            for date in plan.schedule {
                let id = UUID()
                // Awaited inside the serial sync, so the next sync already sees it.
                if await AlarmService.scheduleAlarm(id: id, at: date, title: titles[date] ?? "") { map[id] = date }
            }
            await AlarmService.removeNotifications(prefix: Self.prefix)
        }
        stored = map
        await SessionActivityController.update(session, now: now)
    }

    /// Fallback notifications are `session-<uuid>`.
    private static let prefix = "session"
}

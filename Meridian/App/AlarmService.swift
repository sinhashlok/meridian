import AlarmKit
import Foundation
import SwiftUI  // Color.accent for the alarm tint
import UserNotifications

/// AlarmKit requires a metadata type even when there is nothing to attach.
/// `nonisolated` keeps it off the MainActor so it can be `Sendable`, as AlarmKit requires.
nonisolated struct MeridianAlarmMetadata: AlarmMetadata {}

/// The AlarmKit and notification calls every feature shares (timers, sessions, M7
/// alarms). Each feature decides *what* should ring and keeps its own ids; this only talks
/// to the system. Permissions are asked when something first needs to ring (spec §2).
@MainActor enum AlarmService {
    // MARK: AlarmKit

    /// Asks for Alarms permission if `needed` and not yet asked. `true` if denied.
    static func alarmsDenied(askingIf needed: Bool) async -> Bool {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined, needed {
            _ = try? await manager.requestAuthorization()
        }
        return manager.authorizationState == .denied
    }

    static var alarmsAuthorized: Bool { AlarmManager.shared.authorizationState == .authorized }

    /// What AlarmKit has scheduled right now (the update stream isn't trusted while
    /// suspended, M0.5 test 9, so callers compare against this).
    static var liveAlarmIDs: Set<UUID> {
        Set((try? AlarmManager.shared.alarms)?.map(\.id) ?? [])
    }

    /// A one-off alarm at an absolute instant (`.fixed` keeps its instant across zone
    /// changes, M0.5 test 10). `false` if AlarmKit refused it.
    @discardableResult
    static func scheduleAlarm(id: UUID, at date: Date, title: String) async -> Bool {
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(date),
            attributes: AlarmAttributes<MeridianAlarmMetadata>(presentation: AlarmPresentation(alert: alert(title)),
                                                               tintColor: .accent))
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration)
            return true
        } catch {
            print("Alarm not scheduled (\(title)): \(error)")
            return false
        }
    }

    static func cancelAlarm(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    /// From iOS 26.1 the system draws the Stop button itself and `stopButton` is deprecated.
    private static func alert(_ title: String) -> AlarmPresentation.Alert {
        let resource = LocalizedStringResource(stringLiteral: title)
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: resource)
        } else {
            return AlarmPresentation.Alert(
                title: resource, stopButton: AlarmButton(text: "Stop", textColor: .accent, systemImageName: "stop.circle"))
        }
    }

    // MARK: Notification fallback (decision AI)

    /// Asks for notification permission if `needed` and not yet asked. `true` if denied.
    static func notificationsDenied(askingIf needed: Bool) async -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined, needed {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        return await center.notificationSettings().authorizationStatus == .denied
    }

    /// Pending fallback notifications whose identifier is `<prefix>-<uuid>`.
    static func pendingNotificationIDs(prefix: String) async -> Set<UUID> {
        Set(await UNUserNotificationCenter.current().pendingNotificationRequests().compactMap { request in
            request.identifier.hasPrefix(prefix + "-")
                ? UUID(uuidString: String(request.identifier.dropFirst(prefix.count + 1))) : nil
        })
    }

    static func scheduleNotification(id: UUID, prefix: String, at date: Date, title: String, body: String,
                                     now: Date) async {
        guard date > now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSince(now), repeats: false)
        try? await UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: "\(prefix)-\(id.uuidString)", content: content, trigger: trigger))
    }

    /// Removes the given fallback notifications, or all with `prefix` when `ids` is nil
    /// (Alarms allowed again: nothing should alert twice).
    static func removeNotifications(prefix: String, ids: [UUID]? = nil) async {
        let center = UNUserNotificationCenter.current()
        let identifiers: [String]
        if let ids {
            identifiers = ids.map { "\(prefix)-\($0.uuidString)" }
        } else {
            identifiers = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix + "-") }
        }
        if !identifiers.isEmpty { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    }
}

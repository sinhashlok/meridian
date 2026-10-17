import AlarmKit
import Foundation
import SwiftUI  // Color.accent for the alarm tint
import UserNotifications

/// The AlarmKit and notification calls every feature shares (timers, sessions,
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
    static func scheduleAlarm(id: UUID, at date: Date, title: String, snoozeMinutes: Int? = nil) async -> Bool {
        await schedule(id: id, .fixed(date), title: title, snoozeMinutes: snoozeMinutes)
    }

    /// A wall-clock alarm on the phone's own clock (Local alarms, decision BD): repeats on
    /// ISO `weekdays` (Monday = 1), or rings once when empty.
    @discardableResult
    static func scheduleRelativeAlarm(id: UUID, hour: Int, minute: Int, weekdays: Set<Int>, title: String,
                                      snoozeMinutes: Int?) async -> Bool {
        let repeats: Alarm.Schedule.Relative.Recurrence =
            weekdays.isEmpty ? .never : .weekly(weekdays.sorted().map { isoWeekdays[$0 - 1] })
        let relative = Alarm.Schedule.Relative(time: .init(hour: hour, minute: minute), repeats: repeats)
        return await schedule(id: id, .relative(relative), title: title, snoozeMinutes: snoozeMinutes)
    }

    /// Throws AlarmKit's error, for the DEBUG limit test (decision BP).
    static func trySchedule(id: UUID, _ schedule: Alarm.Schedule, title: String) async throws {
        _ = try await AlarmManager.shared.schedule(id: id, configuration: configuration(schedule, title: title,
                                                                                         snoozeMinutes: nil))
    }

    static func cancelAlarm(id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    private static func schedule(id: UUID, _ schedule: Alarm.Schedule, title: String, snoozeMinutes: Int?) async -> Bool {
        do {
            _ = try await AlarmManager.shared.schedule(
                id: id, configuration: configuration(schedule, title: title, snoozeMinutes: snoozeMinutes))
            return true
        } catch {
            print("Alarm not scheduled (\(title)): \(error)")
            return false
        }
    }

    /// With snooze (decision BG), the alert gets a Snooze button that counts down
    /// `snoozeMinutes` and rings again; the widget draws that countdown.
    private static func configuration(_ schedule: Alarm.Schedule, title: String,
                                      snoozeMinutes: Int?) -> AlarmManager.AlarmConfiguration<MeridianAlarmMetadata> {
        let resource = LocalizedStringResource(stringLiteral: title)
        let presentation = snoozeMinutes == nil
            ? AlarmPresentation(alert: alert(resource, snooze: false))
            : AlarmPresentation(alert: alert(resource, snooze: true),
                                countdown: AlarmPresentation.Countdown(title: "Snoozed · \(title)"))
        let attributes = AlarmAttributes<MeridianAlarmMetadata>(presentation: presentation, tintColor: .accent)
        return AlarmManager.AlarmConfiguration(
            countdownDuration: snoozeMinutes.map { Alarm.CountdownDuration(preAlert: nil, postAlert: TimeInterval($0 * 60)) },
            schedule: schedule, attributes: attributes)
    }

    /// From iOS 26.1 the system draws the Stop button itself and `stopButton` is deprecated.
    private static func alert(_ title: LocalizedStringResource, snooze: Bool) -> AlarmPresentation.Alert {
        let snoozeButton = snooze ? AlarmButton(text: "Snooze", textColor: .textPrimary, systemImageName: "zzz") : nil
        let behavior: AlarmPresentation.Alert.SecondaryButtonBehavior? = snooze ? .countdown : nil
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title, secondaryButton: snoozeButton, secondaryButtonBehavior: behavior)
        } else {
            return AlarmPresentation.Alert(
                title: title, stopButton: AlarmButton(text: "Stop", textColor: .accent, systemImageName: "stop.circle"),
                secondaryButton: snoozeButton, secondaryButtonBehavior: behavior)
        }
    }

    /// `Locale.Weekday` for ISO weekdays 1…7.
    private static let isoWeekdays: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday,
                                                         .saturday, .sunday]

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

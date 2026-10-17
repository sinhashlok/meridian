import Foundation
import MeridianCore

/// Settings and the widget snapshot, kept in the App Group so the widget extension can
/// read what the app writes (spec §6, §7; decisions BR, BX). In both targets.
/// An App Group is like a shared folder two processes may both open: the app writes,
/// widgets only read.
enum SharedDefaults {
    static let appGroup = "group.com.shloksinha.meridian"

    /// The group's `UserDefaults` (falls back to the app's own if the group is missing).
    static let store = UserDefaults(suiteName: appGroup) ?? .standard

    enum Key {
        static let isUTCMode = "isUTCMode"
        static let warnsBeforeClockChanges = "warnsBeforeClockChanges"
        static let weekStart = "weekStart"
        static let defaultWorkStart = "defaultWorkStartMinutes"
        static let defaultWorkEnd = "defaultWorkEndMinutes"
        static let defaultWorkDays = "defaultWorkDays"
    }

    /// `widget-snapshot.json` in the group's folder; `nil` without the App Group entitlement.
    static var snapshotURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "widget-snapshot.json")
    }

    /// What the app last wrote; `nil` before its first write (or without the App Group).
    static func readSnapshot() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        return WidgetSnapshot.decoded(from: data)
    }
}

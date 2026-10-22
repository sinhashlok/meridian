import Foundation
import MeridianCore

/// Settings and the widget snapshot, kept in the App Group so the widget extension can
/// read what the app writes (spec §6, §7; decisions BR, BX). In both targets.
/// An App Group is like a shared folder two processes may both open: the app writes,
/// widgets only read.
enum SharedDefaults {
    /// `MeridianAppGroup` in each target's Info.plist, filled in at build time from
    /// `MERIDIAN_APP_GROUP` in `Config/Signing.xcconfig`, so a clone uses its own group.
    static let appGroup: String = {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "MeridianAppGroup") as? String,
              !id.isEmpty else {
            preconditionFailure("MeridianAppGroup is missing from Info.plist")
        }
        return id
    }()

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

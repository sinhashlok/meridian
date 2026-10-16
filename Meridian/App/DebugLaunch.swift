import Foundation
import MeridianCore

/// Debug-only launch arguments so screenshots can reach any state without tapping.
/// Release builds compile these to nothing.
///
///     xcrun simctl launch booted com.shloksinha.meridian \
///       -MeridianNow 2026-10-15T15:32:00Z \
///       -MeridianZones "Asia/Kolkata=Mumbai,Europe/London=London,America/Los_Angeles=SF" \
///       -MeridianScreen clocks
enum DebugLaunch {
    /// `clocks`, `planner`, `plannerScrub`, `addZone`, `editZone`, `changes`, …
    static var screen: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "MeridianScreen")
        #else
        nil
        #endif
    }

    /// `-MeridianDay 2026-10-25`: the Planner opens on this day instead of today.
    static var plannerDay: CivilDate? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "MeridianDay").flatMap(CivilDate.init(iso:))
        #else
        nil
        #endif
    }

    /// `-MeridianSelect 2026-10-15T15:00:00Z`: the Planner's selected time.
    static var plannerSelection: Date? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "MeridianSelect").flatMap { try? EpochParser.parseISO8601($0).date }
        #else
        nil
        #endif
    }

    /// `-MeridianBottom 1`: scroll views start at the bottom, to shoot what's below the fold.
    static var startsAtBottom: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "MeridianBottom")
        #else
        false
        #endif
    }

    /// `-MeridianWarn 1`: show the Clocks warn-before-clocks-change banner (a Settings
    /// toggle from M8).
    static var warnsBeforeClockChanges: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "MeridianWarn")
        #else
        false
        #endif
    }

    /// Replaces saved zones on launch; the first one is home.
    static var zones: [(zone: Zone, name: String)]? {
        #if DEBUG
        guard let text = UserDefaults.standard.string(forKey: "MeridianZones") else { return nil }
        return text.split(separator: ",").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let zone = Zone(String(parts[0])) else { return nil }
            return (zone, parts.count > 1 ? String(parts[1]) : ZoneCatalog.displayName(for: zone))
        }
        #else
        nil
        #endif
    }
}

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
    /// `clocks`, `planner`, `addZone`, `editZone`, `changes`, …
    static var screen: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "MeridianScreen")
        #else
        nil
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

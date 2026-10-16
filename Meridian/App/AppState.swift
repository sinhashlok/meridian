import Foundation
import MeridianCore
import Observation

/// App-wide UI state shared by every tab through the environment.
/// In-memory for M0; moves to App Group UserDefaults in M8 so widgets can read
/// the UTC display setting (spec §6).
@Observable final class AppState {
    /// UTC pill flipped on: every displayed time is shown in UTC (spec §4.1).
    var isUTCMode = false
    var isSettingsPresented = false

    /// Debug builds only: `-MeridianNow 2026-10-15T15:32:00Z` freezes the clock so
    /// screenshots match the fixtures and design boards. Release builds ignore it.
    let frozenNow: Date?

    init() {
        #if DEBUG
        frozenNow = UserDefaults.standard.string(forKey: "MeridianNow")
            .flatMap { try? EpochParser.parseISO8601($0).date }
        #else
        frozenNow = nil
        #endif
    }

    /// "Now" for every screen. Pass the `TimelineView` date so live views keep ticking
    /// unless the clock is frozen.
    func now(_ live: Date = .now) -> Date { frozenNow ?? live }
}

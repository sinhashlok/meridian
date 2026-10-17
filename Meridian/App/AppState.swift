import Foundation
import MeridianCore
import Observation

/// A request to show `start` on the Planner, on `day` in its reference zone.
struct PlannerJump: Equatable {
    let day: CivilDate
    let start: Date
}

/// App-wide UI state shared by every tab through the environment. Settings are kept in
/// App Group `UserDefaults` (`SharedDefaults`) so widgets can read the UTC display
/// setting (spec §6, decision BX); `didSet` writes each change straight through.
@Observable final class AppState {
    /// UTC pill flipped on: every displayed time is shown in UTC (spec §4.1).
    var isUTCMode: Bool { didSet { defaults.set(isUTCMode, forKey: SharedDefaults.Key.isUTCMode) } }
    var isSettingsPresented = false
    /// The selected tab. First launch opens Zones (spec §2); `-MeridianTab` picks another.
    var tab = DebugLaunch.tab ?? "zones"
    /// Set to open Zones › Planner on a window (Sessions' meeting line); the Planner
    /// applies it and clears it.
    var plannerJump: PlannerJump?

    // MARK: Settings (spec §2)

    /// Warn before clocks change: off by default; an in-app banner only.
    var warnsBeforeClockChanges: Bool {
        didSet { defaults.set(warnsBeforeClockChanges, forKey: SharedDefaults.Key.warnsBeforeClockChanges) }
    }
    /// Orders weekday chips and day lists (decision BY).
    var weekStart: WeekStart { didSet { defaults.set(weekStart.rawValue, forKey: SharedDefaults.Key.weekStart) } }
    /// What new zones start with (decision BZ).
    var defaultWorkStart: ClockTime {
        didSet { defaults.set(defaultWorkStart.minutesAfterMidnight, forKey: SharedDefaults.Key.defaultWorkStart) }
    }
    var defaultWorkEnd: ClockTime {
        didSet { defaults.set(defaultWorkEnd.minutesAfterMidnight, forKey: SharedDefaults.Key.defaultWorkEnd) }
    }
    /// ISO weekdays, sorted.
    var defaultWorkDays: [Int] { didSet { defaults.set(defaultWorkDays, forKey: SharedDefaults.Key.defaultWorkDays) } }

    /// Debug builds only: `-MeridianNow 2026-10-15T15:32:00Z` freezes the clock so
    /// screenshots match the fixtures and design boards. Release builds ignore it.
    let frozenNow: Date?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = SharedDefaults.store) {
        typealias Key = SharedDefaults.Key
        self.defaults = defaults
        isUTCMode = defaults.bool(forKey: Key.isUTCMode)
        warnsBeforeClockChanges = defaults.bool(forKey: Key.warnsBeforeClockChanges)
        weekStart = defaults.string(forKey: Key.weekStart).flatMap(WeekStart.init(rawValue:)) ?? .followLocale
        defaultWorkStart = ClockTime(minutesAfterMidnight: defaults.object(forKey: Key.defaultWorkStart) as? Int ?? 9 * 60)
        defaultWorkEnd = ClockTime(minutesAfterMidnight: defaults.object(forKey: Key.defaultWorkEnd) as? Int ?? 18 * 60)
        defaultWorkDays = defaults.array(forKey: Key.defaultWorkDays) as? [Int] ?? [1, 2, 3, 4, 5]
        #if DEBUG
        frozenNow = UserDefaults.standard.string(forKey: "MeridianNow")
            .flatMap { try? EpochParser.parseISO8601($0).date }
        // Launch arguments win for screenshots; set in init, so `didSet` doesn't store them.
        if let utc = DebugLaunch.flag("MeridianUTC") { isUTCMode = utc }                 // -MeridianUTC 1
        if let warn = DebugLaunch.flag("MeridianWarn") { warnsBeforeClockChanges = warn }  // -MeridianWarn 1
        isSettingsPresented = DebugLaunch.screen == "settings"
        #else
        frozenNow = nil
        #endif
    }

    /// "Now" for every screen. Pass the `TimelineView` date so live views keep ticking
    /// unless the clock is frozen.
    func now(_ live: Date = .now) -> Date { frozenNow ?? live }

    /// The first day of the week as an ISO weekday (Monday = 1).
    var firstWeekday: Int { weekStart.firstDay(for: .current) }

    /// Work hours and days for a new zone; 09:00–18:00 if the saved hours don't make a day.
    var zoneDefaults: ZoneDefaults {
        defaultWorkStart < defaultWorkEnd
            ? ZoneDefaults(workStart: defaultWorkStart, workEnd: defaultWorkEnd, workDays: defaultWorkDays)
            : ZoneDefaults(workDays: defaultWorkDays)
    }
}

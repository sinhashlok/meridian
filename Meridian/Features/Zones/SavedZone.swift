import Foundation
import MeridianCore
import SwiftData

/// A zone the user keeps on Clocks and the Planner (spec §7 `Zone`).
/// Stores the IANA id and wall-clock settings, never an offset or abbreviation.
@Model
final class SavedZone {
    var ianaID: String
    /// Display name ("Mumbai", "SF"); editable.
    var name: String
    var isHome: Bool
    /// Minutes after local midnight (09:00 = 540).
    var workStartMinutes: Int
    var workEndMinutes: Int
    /// ISO weekdays: Monday = 1 … Sunday = 7.
    var workDays: [Int]
    /// Position in Clocks and the Planner.
    var order: Int

    init(ianaID: String, name: String, isHome: Bool, order: Int,
         workStart: ClockTime = ClockTime(9, 0), workEnd: ClockTime = ClockTime(18, 0),
         workDays: [Int] = [1, 2, 3, 4, 5]) {
        self.ianaID = ianaID
        self.name = name
        self.isHome = isHome
        self.order = order
        self.workStartMinutes = workStart.minutesAfterMidnight
        self.workEndMinutes = workEnd.minutesAfterMidnight
        self.workDays = workDays
    }

    /// `nil` only if the stored id stopped being a valid zone (e.g. a removed alias).
    var zone: Zone? { Zone(ianaID) }

    var workStart: ClockTime { ClockTime(minutesAfterMidnight: workStartMinutes) }
    var workEnd: ClockTime { ClockTime(minutesAfterMidnight: workEndMinutes) }

    /// What OverlapEngine works with.
    var plannerZone: PlannerZone? {
        guard let zone, workStart < workEnd else { return nil }
        return PlannerZone(zone: zone, name: name, workStart: workStart, workEnd: workEnd, workDays: Set(workDays))
    }
}

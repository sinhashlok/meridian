import Foundation
import MeridianCore
import SwiftData

/// A saved timer (spec §7 `TimerItem`, decision AO): the Core `CountdownTimer` as JSON,
/// like `SavedFiscalProfile`, plus the id of the alarm scheduled for it.
@Model
final class SavedTimer {
    var data: Data
    /// The AlarmKit alarm (or fallback notification) ringing at the end; `nil` while
    /// paused or finished. A new id each time it's rescheduled (decision AH).
    var alarmID: UUID?
    /// Creation order; the list itself is sorted by `TimerText.sorted`.
    var order: Int

    init(timer: CountdownTimer, order: Int) {
        self.data = (try? JSONEncoder().encode(timer)) ?? Data()
        self.order = order
    }

    /// `nil` only if the stored JSON no longer decodes.
    var timer: CountdownTimer? {
        get { try? JSONDecoder().decode(CountdownTimer.self, from: data) }
        set { if let newValue, let encoded = try? JSONEncoder().encode(newValue) { data = encoded } }
    }
}

/// Every change to saved timers goes through here, so the alarms always match them.
enum TimerStore {
    /// Decoded timers, rows kept alongside so cards can change them.
    static func timers(from saved: [SavedTimer]) -> [(row: SavedTimer, timer: CountdownTimer)] {
        saved.compactMap { row in row.timer.map { (row, $0) } }
    }

    static func add(_ timer: CountdownTimer, to saved: [SavedTimer], in context: ModelContext) {
        let row = SavedTimer(timer: timer, order: (saved.map(\.order).max() ?? -1) + 1)
        context.insert(row)
    }

    /// Applies a Core change (pause, +1 min, …) to one row.
    static func update(_ row: SavedTimer, _ change: (inout CountdownTimer) -> Void) {
        guard var timer = row.timer else { return }
        change(&timer)
        row.timer = timer
    }

    static func delete(_ row: SavedTimer, in context: ModelContext) {
        context.delete(row)
    }

    /// `-MeridianTimers demo`: the TimerUntil board's two timers, relative to `now`
    /// (06:42 left of 10 min; Until 02:00 UTC). `live`: the same on the real clock, for
    /// the Live Activity. `short`: one 20-second timer on the real clock, to check
    /// ringing. `none`: no timers. Each replaces any saved timers.
    static func applyDebugLaunch(_ saved: [SavedTimer], now frozenNow: Date, in context: ModelContext) {
        guard let mode = DebugLaunch.timers, ["demo", "live", "short", "none"].contains(mode) else { return }
        let now = mode == "demo" ? frozenNow : .now
        for row in saved { context.delete(row) }
        if mode == "none" { return }
        if mode == "short" {
            context.insert(SavedTimer(timer: .duration(seconds: 20, name: "Smoke test", now: .now), order: 0))
            return
        }
        context.insert(SavedTimer(timer: .duration(seconds: 600, name: "Standup prep", now: now.addingTimeInterval(-198)),
                                  order: 0))
        context.insert(SavedTimer(timer: .until(hour: 2, minute: 0, in: .utc, occurrence: .first,
                                                name: "Deploy window", now: now),
                                  order: 1))
    }
}

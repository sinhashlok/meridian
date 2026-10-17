import ActivityKit
import Foundation

/// The timer Live Activity (decision AQ). Compiled into both the app (which starts and
/// updates it) and MeridianWidgets (which draws it), because ActivityKit matches the two
/// sides by this type. Everything is pre-formatted by Core's `TimerAlarmPlan.activity`,
/// so the widget needs no time maths.
///
/// `nonisolated`: the app target defaults to MainActor, but ActivityKit encodes this
/// off the main thread, so it must be plain `Sendable` data.
nonisolated struct TimerActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// The shown timer, for the Pause / +1 min / Cancel buttons.
        var timerID: UUID
        /// Soonest timer's name.
        var title: String
        /// `Ends 21:16 IST`, `Until 02:00 UTC` or `Paused`.
        var caption: String
        /// Running: the system counts down to this.
        var endDate: Date?
        /// Running duration timers: the bar drains from here to `endDate`.
        var progressStart: Date?
        /// Paused: frozen time left (`06:42`) and bar fraction.
        var pausedRemaining: String?
        var pausedFraction: Double?
        /// `+2 more`.
        var more: String?
    }
}

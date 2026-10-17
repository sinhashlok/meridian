import ActivityKit
import Foundation

/// The session Live Activity (decision AZ). Compiled into both the app (which starts and
/// updates it) and MeridianWidgets (which draws it). Everything is pre-formatted by Core's
/// `SessionActivityContent`, so the widget needs no time maths.
nonisolated struct SessionActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// `Focus · 1 of 4`.
        var phase: String
        /// `Ends 21:28 IST` or `Paused`.
        var ends: String
        var isFocus: Bool
        /// Running: the system counts down to this.
        var endDate: Date?
        /// Running: the ring/bar drains from here to `endDate`.
        var phaseStart: Date?
        /// Paused: the frozen time left and ring fraction.
        var pausedRemaining: String?
        var pausedFraction: Double?
        var meetingTitle: String?
        var meetingDetail: String?
    }
}

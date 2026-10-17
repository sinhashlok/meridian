import Foundation

/// What the session Live Activity shows (decision AZ, boards LiveActivity and Island).
/// The app copies it into the ActivityKit content state; the widget only lays it out.
public struct SessionActivityContent: Equatable, Sendable {
    /// `Focus · 1 of 4`.
    public let phase: String
    /// `Ends 21:28 IST` or `Paused`.
    public let ends: String
    /// Focus rings are accent, breaks `textSecondary` (spec §4.5).
    public let isFocus: Bool
    /// Running: the system counts down to the phase end (`Text(timerInterval:)`).
    public let endDate: Date?
    /// Running: the ring/bar drains from here to `endDate` (the phase end minus its
    /// planned length, so it stays right after a pause or +5 min).
    public let phaseStart: Date?
    /// Paused: the frozen time left and ring fraction.
    public let pausedRemaining: String?
    public let pausedFraction: Double?
    /// The meeting line (decision AY), split as on board LiveActivity: `Best compromise
    /// in 21 min · 16:00 UTC` over `3 of 3 awake · Mumbai in stretch`.
    public let meetingTitle: String?
    public let meetingDetail: String?

    public init(phase: String, ends: String, isFocus: Bool, endDate: Date?, phaseStart: Date?, pausedRemaining: String?,
                pausedFraction: Double?, meetingTitle: String?, meetingDetail: String?) {
        self.phase = phase
        self.ends = ends
        self.isFocus = isFocus
        self.endDate = endDate
        self.phaseStart = phaseStart
        self.pausedRemaining = pausedRemaining
        self.pausedFraction = pausedFraction
        self.meetingTitle = meetingTitle
        self.meetingDetail = meetingDetail
    }

    /// `nil` once the session is done: the activity ends.
    public static func make(_ session: PomodoroSession, now: Date, display: Zone, meeting: MeetingLine?)
        -> SessionActivityContent? {
        guard let index = session.currentIndex(at: now) else { return nil }
        let phase = session.phases[index]
        let text = SessionText.card(session, now: now, display: display)
        let isPaused = session.pausedAt != nil
        return SessionActivityContent(
            phase: text.phase, ends: text.status, isFocus: phase.kind == .focus,
            endDate: isPaused ? nil : phase.end,
            phaseStart: isPaused ? nil : phase.end.addingTimeInterval(-TimeInterval(phase.seconds)),
            pausedRemaining: isPaused ? text.remaining : nil,
            pausedFraction: isPaused ? session.fraction(at: now) : nil,
            meetingTitle: meeting?.headline, meetingDetail: meeting?.counts)
    }
}

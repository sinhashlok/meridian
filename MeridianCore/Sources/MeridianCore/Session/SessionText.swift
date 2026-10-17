import Foundation

/// One dot per cycle under the phase line (decision AX).
public enum CycleDot: Sendable { case done, current, upcoming }

/// Every string on the Sessions screen (board Sessions, decisions AU and AX).
public struct SessionCardText: Equatable, Sendable {
    /// `Focus · 1 of 4`, `Break · 1 of 4`, `4 of 4 done`.
    public let phase: String
    /// `18:42` (the phase's time left).
    public let remaining: String
    /// `Ends 21:28 IST`, `Paused`, `Session done · 1 h 40 min focused`.
    public let status: String
    public let dots: [CycleDot]
    /// The shown zone changes clocks before this phase ends (spec §5.3).
    public let notes: [String]
}

/// Session wording. `display` is the phone's zone, or UTC with the pill on.
public enum SessionText {
    public static func card(_ session: PomodoroSession, now: Date, display: Zone) -> SessionCardText {
        let cycles = session.lengths.cycles
        guard let index = session.currentIndex(at: now) else {
            let focused = session.focusRecords(until: now).map(\.seconds).reduce(0, +)
            return SessionCardText(phase: "\(cycles) of \(cycles) done", remaining: TimerText.remaining(seconds: 0),
                                   status: "Session done · \(minutesText(focused)) focused",
                                   dots: Array(repeating: .done, count: cycles), notes: [])
        }
        let phase = session.phases[index]
        let dots = (1...cycles).map { cycle -> CycleDot in
            cycle < phase.cycle ? .done : cycle == phase.cycle ? .current : .upcoming
        }
        let isPaused = session.pausedAt != nil
        return SessionCardText(
            phase: "\(phase.kind == .focus ? "Focus" : "Break") · \(phase.cycle) of \(cycles)",
            remaining: TimerText.remaining(seconds: session.remainingSeconds(at: now)),
            status: isPaused ? "Paused" : "Ends " + TimerText.timeOnDay(phase.end, in: display, now: now),
            dots: dots,
            notes: isPaused ? [] : ZoneClock.clockChangeNotes(in: display, from: now, to: phase.end))
    }

    /// `Focused today: 40 min` (decision BB): the focus that falls on today in `display`;
    /// a record across midnight counts its share. `nil` when there is none.
    public static func focusedToday(_ records: [FocusRecord], now: Date, display: Zone) -> String? {
        let today = ZoneClock.local(now, in: display).date
        let day = DateInterval(start: ZoneClock.startOfDay(today, in: display),
                               end: ZoneClock.startOfDay(today.adding(days: 1), in: display))
        let seconds = records.reduce(0.0) { total, record in
            guard record.interval.duration > 0, let overlap = record.interval.intersection(with: day) else { return total }
            return total + overlap.duration / record.interval.duration * Double(record.seconds)
        }
        return seconds >= 60 ? "Focused today: \(minutesText(Int(seconds)))" : nil
    }

    /// `1 h 40 min`, `1 h`, `50 min`: whole minutes, rounded down.
    static func minutesText(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

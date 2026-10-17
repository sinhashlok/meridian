import Foundation

/// Pomodoro lengths (spec §4.5 defaults 25/5, 4 cycles; decision AW).
public struct SessionLengths: Codable, Hashable, Sendable {
    public let focusMinutes: Int
    public let breakMinutes: Int
    public let cycles: Int

    public init(focusMinutes: Int, breakMinutes: Int, cycles: Int) {
        precondition(focusMinutes > 0 && breakMinutes > 0 && cycles > 0, "lengths must be positive")
        self.focusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.cycles = cycles
    }

    public static let standard = SessionLengths(focusMinutes: 25, breakMinutes: 5, cycles: 4)
}

/// One focus or break, with real instants. `seconds` is its planned length (+5 min taps
/// included); `pausedSeconds` is time spent paused inside it, which isn't focus.
public struct SessionPhase: Codable, Hashable, Sendable {
    public enum Kind: Codable, Hashable, Sendable {
        case focus
        /// A break ("break" is a Swift keyword).
        case rest
    }

    public let kind: Kind
    /// 1-based; a break belongs to the focus before it.
    public let cycle: Int
    public internal(set) var start: Date
    public internal(set) var end: Date
    public internal(set) var seconds: Int
    public internal(set) var pausedSeconds: Int
}

/// A finished (or partly done) focus phase for the history (spec §7 `Session`).
public struct FocusRecord: Codable, Hashable, Sendable {
    public let interval: DateInterval
    /// Time actually focused: the interval minus pauses.
    public let seconds: Int

    public init(interval: DateInterval, seconds: Int) {
        self.interval = interval
        self.seconds = seconds
    }
}

/// An alarm at a phase boundary (decision AV), named for what starts then.
public struct SessionAlarm: Equatable, Sendable {
    public let fireDate: Date
    public let title: String
}

/// A Pomodoro session (spec §4.5, decision AT): every phase is planned with real instants
/// at Start, and pause/+5/skip move those instants. Nothing counts down in memory, so the
/// session advances with the app killed or the phone locked; "where am I" is computed
/// from `now`. Focus 1, Break 1, …, Focus N: it ends after the last focus (decision AU).
public struct PomodoroSession: Codable, Hashable, Sendable {
    public enum Status: Equatable, Sendable {
        /// The phase index in progress.
        case running(Int)
        case paused(Int)
        case done
    }

    public let lengths: SessionLengths
    public private(set) var phases: [SessionPhase]
    /// When the session was paused; `nil` while running.
    public private(set) var pausedAt: Date?

    public static func start(_ lengths: SessionLengths, at now: Date) -> PomodoroSession {
        var phases: [SessionPhase] = []
        var cursor = now
        for cycle in 1...lengths.cycles {
            let kinds: [(SessionPhase.Kind, Int)] = cycle < lengths.cycles
                ? [(.focus, lengths.focusMinutes), (.rest, lengths.breakMinutes)] : [(.focus, lengths.focusMinutes)]
            for (kind, minutes) in kinds {
                let end = cursor.addingTimeInterval(TimeInterval(minutes * 60))
                phases.append(SessionPhase(kind: kind, cycle: cycle, start: cursor, end: end, seconds: minutes * 60,
                                           pausedSeconds: 0))
                cursor = end
            }
        }
        return PomodoroSession(lengths: lengths, phases: phases, pausedAt: nil)
    }

    /// When the last phase ends.
    public var endDate: Date { phases.last?.end ?? .distantPast }

    public func status(at now: Date) -> Status {
        guard let index = currentIndex(at: now) else { return .done }
        return pausedAt == nil ? .running(index) : .paused(index)
    }

    /// The phase in progress (or paused in); `nil` once the session is done.
    public func currentIndex(at now: Date) -> Int? {
        let t = effective(now)
        return phases.firstIndex { $0.end > t }
    }

    /// Seconds left in the current phase (frozen while paused).
    public func remaining(at now: Date) -> TimeInterval {
        guard let index = currentIndex(at: now) else { return 0 }
        return phases[index].end.timeIntervalSince(effective(now))
    }

    /// Whole seconds left, rounded up (like timers, decision AK).
    public func remainingSeconds(at now: Date) -> Int {
        Int(remaining(at: now).rounded(.up))
    }

    /// Fraction of the current phase still to go, 1 → 0 (the ring drains; decision AX).
    public func fraction(at now: Date) -> Double {
        guard let index = currentIndex(at: now) else { return 0 }
        return remaining(at: now) / TimeInterval(phases[index].seconds)
    }

    public mutating func pause(at now: Date) {
        guard pausedAt == nil, currentIndex(at: now) != nil else { return }
        pausedAt = now
    }

    /// Every boundary still ahead moves later by the time spent paused.
    public mutating func resume(at now: Date) {
        guard let pausedAt else { return }
        let delta = now.timeIntervalSince(pausedAt)
        if let index = currentIndex(at: pausedAt) {
            phases[index].end.addTimeInterval(delta)
            phases[index].pausedSeconds += Int(delta.rounded())
            shift(after: index, by: delta)
        }
        self.pausedAt = nil
    }

    /// The current phase gets 5 more minutes; the rest move with it.
    public mutating func addFiveMinutes(at now: Date) {
        guard let index = currentIndex(at: now) else { return }
        phases[index].end.addTimeInterval(300)
        phases[index].seconds += 300
        shift(after: index, by: 300)
    }

    /// Ends the current phase now (at the pause, if paused); the rest move earlier.
    public mutating func skip(at now: Date) {
        guard let index = currentIndex(at: now) else { return }
        let t = effective(now)
        let delta = phases[index].end.timeIntervalSince(t)
        phases[index].end = t
        shift(after: index, by: -delta)
    }

    /// One alarm per boundary still ahead (decision AV): `Break · 5 min`, `Focus 2 of 4`,
    /// `Session done`. None while paused: there is no fixed time to ring at.
    public func upcomingAlarms(at now: Date) -> [SessionAlarm] {
        guard pausedAt == nil else { return [] }
        return phases.indices.filter { phases[$0].end > now }.map { index in
            let title: String
            if index + 1 < phases.count {
                let next = phases[index + 1]
                title = next.kind == .rest ? "Break · \(lengths.breakMinutes) min"
                    : "Focus \(next.cycle) of \(lengths.cycles)"
            } else {
                title = "Session done"
            }
            return SessionAlarm(fireDate: phases[index].end, title: title)
        }
    }

    /// Focus done so far, cut at `now` (and at the pause, if paused). For the history and
    /// the done summary.
    public func focusRecords(until now: Date) -> [FocusRecord] {
        let t = effective(now)
        return phases.filter { $0.kind == .focus && $0.start < t }.map { phase in
            let end = min(phase.end, t)
            let seconds = Int(end.timeIntervalSince(phase.start).rounded()) - phase.pausedSeconds
            return FocusRecord(interval: DateInterval(start: phase.start, end: end), seconds: max(0, seconds))
        }
    }

    // MARK: Private

    /// The session's clock: stopped at the pause while paused.
    private func effective(_ now: Date) -> Date { pausedAt ?? now }

    private mutating func shift(after index: Int, by delta: TimeInterval) {
        for later in phases.indices where later > index {
            phases[later].start.addTimeInterval(delta)
            phases[later].end.addTimeInterval(delta)
        }
    }
}

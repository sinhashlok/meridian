import Foundation

/// Where an Until timer ends: a wall time in a zone, resolved once to an instant with the
/// gap/overlap rule (spec §5.2, decision AM). Kept so the card can explain the result.
public struct UntilTarget: Codable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int
    public let zoneID: String
    /// What the user picked for a repeated hour.
    public let occurrence: Occurrence
    /// The local date in `zoneID` the target fell on.
    public let date: CivilDate
    /// How the rule resolved it: exact, skipped (gap) or repeated.
    public let resolution: Resolution.Kind
    /// The occurrence actually used: `.second` when the first had already passed.
    public let used: Occurrence

    public var zone: Zone { Zone(zoneID) ?? .utc }

    /// The next instant after `now` when the wall clock in `zone` reads `hour:minute`.
    /// A skipped time moves to the next valid time; a repeated one uses `occurrence`, or
    /// the second if the first has already passed (the clock will read it again).
    static func next(hour: Int, minute: Int, in zone: Zone, occurrence: Occurrence,
                     after now: Date) -> (target: UntilTarget, instant: Date) {
        let today = ZoneClock.local(now, in: zone).date
        for offset in 0...2 {
            let date = today.adding(days: offset)
            let time = LocalDateTime(date: date, hour: hour, minute: minute)
            func target(_ kind: Resolution.Kind, used: Occurrence) -> UntilTarget {
                UntilTarget(hour: hour, minute: minute, zoneID: zone.id, occurrence: occurrence,
                            date: date, resolution: kind, used: used)
            }
            let chosen = ZoneClock.resolve(time, in: zone, occurrence: occurrence)
            if chosen.instant > now { return (target(chosen.kind, used: occurrence), chosen.instant) }
            if chosen.kind == .repeated, occurrence == .first {
                let second = ZoneClock.resolve(time, in: zone, occurrence: .second)
                if second.instant > now { return (target(.repeated, used: .second), second.instant) }
            }
        }
        preconditionFailure("no \(hour):\(minute) in \(zone.id) within 3 days of \(now)")
    }
}

/// A named countdown (spec §4.4). Stores instants, never a running counter (CLAUDE.md):
/// running = `endDate`, paused = `pausedRemaining`. Duration timers measure elapsed time,
/// so a clock change never moves them; Until timers end at a resolved wall time.
public struct CountdownTimer: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: Codable, Hashable, Sendable {
        /// `addedSeconds` counts the +1 min taps; Restart drops them.
        case duration(baseSeconds: Int, addedSeconds: Int)
        case until(UntilTarget)
    }

    public enum Status: Sendable { case running, paused, finished }

    public let id: UUID
    public var name: String
    public private(set) var kind: Kind
    /// When it ends (running or finished). `nil` while paused.
    public private(set) var endDate: Date?
    /// Seconds left when paused. Duration timers only.
    public private(set) var pausedRemaining: TimeInterval?

    private init(id: UUID, name: String, kind: Kind, endDate: Date?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.endDate = endDate
    }

    /// A running duration timer started at `now`.
    public static func duration(seconds: Int, name: String = "", id: UUID = UUID(), now: Date) -> CountdownTimer {
        CountdownTimer(id: id, name: name, kind: .duration(baseSeconds: seconds, addedSeconds: 0),
                       endDate: now.addingTimeInterval(TimeInterval(seconds)))
    }

    /// A running Until timer ending at the next `hour:minute` in `zone` (decision AM).
    public static func until(hour: Int, minute: Int, in zone: Zone, occurrence: Occurrence, name: String = "",
                             id: UUID = UUID(), now: Date) -> CountdownTimer {
        let next = UntilTarget.next(hour: hour, minute: minute, in: zone, occurrence: occurrence, after: now)
        return CountdownTimer(id: id, name: name, kind: .until(next.target), endDate: next.instant)
    }

    /// Length including +1 min taps. `nil` for Until timers.
    public var totalSeconds: Int? {
        guard case .duration(let base, let added) = kind else { return nil }
        return base + added
    }

    public var isDuration: Bool { totalSeconds != nil }

    /// Seconds left (never negative).
    public func remaining(at now: Date) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        return max(0, (endDate ?? now).timeIntervalSince(now))
    }

    /// Whole seconds left, rounded up: 10:00 at the start, 00:00 only at the end (decision AK).
    public func remainingSeconds(at now: Date) -> Int {
        Int(remaining(at: now).rounded(.up))
    }

    public func status(at now: Date) -> Status {
        if pausedRemaining != nil { return .paused }
        return remaining(at: now) > 0 ? .running : .finished
    }

    /// Fraction still to go, 1 → 0 (the bar drains; decision AK). `nil` for Until timers.
    public func progress(at now: Date) -> Double? {
        guard let total = totalSeconds, total > 0 else { return nil }
        return remaining(at: now) / TimeInterval(total)
    }

    public mutating func pause(at now: Date) {
        guard isDuration, status(at: now) == .running else { return }
        pausedRemaining = remaining(at: now)
        endDate = nil
    }

    public mutating func resume(at now: Date) {
        guard let pausedRemaining else { return }
        endDate = now.addingTimeInterval(pausedRemaining)
        self.pausedRemaining = nil
    }

    /// +1 min on a running or paused duration timer.
    public mutating func addMinute(at now: Date) {
        guard case .duration(let base, let added) = kind, status(at: now) != .finished else { return }
        kind = .duration(baseSeconds: base, addedSeconds: added + 60)
        if let pausedRemaining {
            self.pausedRemaining = pausedRemaining + 60
        } else {
            endDate = endDate?.addingTimeInterval(60)
        }
    }

    /// Starts a duration timer again at its original length.
    public mutating func restart(at now: Date) {
        guard case .duration(let base, _) = kind else { return }
        kind = .duration(baseSeconds: base, addedSeconds: 0)
        endDate = now.addingTimeInterval(TimeInterval(base))
        pausedRemaining = nil
    }
}

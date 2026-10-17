import Foundation

/// Every string on a timer card (board TimerUntil, decisions AJ–AM).
public struct TimerCardText: Equatable, Sendable {
    /// The name, or `10 min` / `02:00 UTC` when it has none.
    public let title: String
    /// `Duration · 10 min` or `Until` (the view sets the letter case).
    public let tag: String
    /// `06:42`, `10:20:42`.
    public let remaining: String
    /// `Ends 21:16 IST`, `Paused`, `Done · ended 21:16 IST`, `Passed 10 min ago`;
    /// `nil` for a running Until timer (its Until lines say it).
    public let status: String?
    /// Until timers: `02:00 UTC`, shown after "Until".
    public let untilTime: String?
    /// Until timers: `07:30 IST on this phone · Fri`; `nil` when the target zone is the shown zone.
    public let localLine: String?
    /// DST notes: the gap/overlap rule, or the shown zone changing clocks before the end.
    public let notes: [String]
}

/// The Until sheet's live preview.
public struct UntilPreview: Equatable, Sendable {
    /// `Ends Fri 07:30 IST · in 10 h 20 min`.
    public let ends: String
    /// The gap/overlap note, if the rule decided the result.
    public let note: String?
    /// The chosen time happens twice: show First | Second.
    public let isRepeated: Bool
}

/// Timer wording. `display` is the zone times are shown in: the phone's, or UTC when the
/// pill is on (`displayIsPhone` false).
public enum TimerText {
    /// `MM:SS` under an hour, `HH:MM:SS` from an hour (decision AK).
    public static func remaining(seconds: Int) -> String {
        let s = max(0, seconds)
        let hours = s / 3600, minutes = s % 3600 / 60, secs = s % 60
        return hours > 0
            ? String(format: "%02d:%02d:%02d", hours, minutes, secs)
            : String(format: "%02d:%02d", minutes, secs)
    }

    /// `10 min`, `1 h 30 min`, `45 s`, `1 h 1 min 1 s`.
    public static func durationText(seconds: Int) -> String {
        let hours = seconds / 3600, minutes = seconds % 3600 / 60, secs = seconds % 60
        let parts = [(hours, "h"), (minutes, "min"), (secs, "s")].filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? "0 s" : parts.joined(separator: " ")
    }

    public static func card(_ timer: CountdownTimer, now: Date, display: Zone, displayIsPhone: Bool) -> TimerCardText {
        let status = timer.status(at: now)
        let remaining = remaining(seconds: timer.remainingSeconds(at: now))

        switch timer.kind {
        case .duration:
            let total = durationText(seconds: timer.totalSeconds ?? 0)
            var notes: [String] = []
            let line: String
            switch status {
            case .paused:
                line = "Paused"
            case .running:
                let end = timer.endDate!
                line = "Ends " + timeOnDay(end, in: display, now: now)
                notes += ZoneClock.clockChangeNotes(in: display, from: now, to: end)
            case .finished:
                line = "Done · ended " + timeOnDay(timer.endDate!, in: display, now: now)
            }
            return TimerCardText(title: timer.name.isEmpty ? total : timer.name, tag: "Duration · \(total)",
                                 remaining: remaining, status: line, untilTime: nil, localLine: nil, notes: notes)

        case .until(let target):
            let end = timer.endDate!
            let zone = target.zone
            let untilTime = ZoneClock.timeWithAbbreviation(end, in: zone)
            var localLine: String?
            if !sameZone(zone, display) {
                localLine = ZoneClock.timeWithAbbreviation(end, in: display) + (displayIsPhone ? " on this phone" : "")
                if isOtherDay(end, in: display, now: now) {
                    localLine! += " · " + ZoneClock.local(end, in: display).date.weekdayText
                }
            }
            let ruleNote = untilNote(target, instant: end)
            var notes = ruleNote.map { [$0] } ?? []
            var line: String?
            if status == .finished {
                line = "Passed " + EpochText.relative(epoch(end), now: now)
            } else if ruleNote == nil || !sameZone(zone, display) {
                // A §5.2 note already says this zone changes clocks; don't say it twice.
                notes += ZoneClock.clockChangeNotes(in: display, from: now, to: end)
            }
            return TimerCardText(title: timer.name.isEmpty ? untilTime : timer.name, tag: "Until",
                                 remaining: remaining, status: line, untilTime: untilTime, localLine: localLine,
                                 notes: notes)
        }
    }

    public static func untilPreview(hour: Int, minute: Int, in zone: Zone, occurrence: Occurrence, now: Date,
                                    display: Zone) -> UntilPreview {
        let next = UntilTarget.next(hour: hour, minute: minute, in: zone, occurrence: occurrence, after: now)
        let ends = "Ends " + timeOnDay(next.instant, in: display, now: now) + " · "
            + EpochText.relative(epoch(next.instant), now: now)
        return UntilPreview(ends: ends, note: untilNote(next.target, instant: next.instant),
                            isRepeated: next.target.resolution == .repeated)
    }

    /// `2 running`, `1 running · 1 paused · 1 done`; `nil` with no timers.
    public static func header(_ timers: [CountdownTimer], now: Date) -> String? {
        let statuses = timers.map { $0.status(at: now) }
        let parts = [(CountdownTimer.Status.running, "running"), (.paused, "paused"), (.finished, "done")]
            .map { status, word in (statuses.filter { $0 == status }.count, word) }
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Done first (they need dismissing), then running by end, then paused by time left.
    /// Equal keys keep their input order.
    public static func sorted(_ timers: [CountdownTimer], now: Date) -> [CountdownTimer] {
        func key(_ timer: CountdownTimer) -> (Int, TimeInterval) {
            switch timer.status(at: now) {
            case .finished: (0, timer.endDate!.timeIntervalSince1970)
            case .running: (1, timer.endDate!.timeIntervalSince1970)
            case .paused: (2, timer.remaining(at: now))
            }
        }
        return timers.enumerated()
            .sorted {
                let a = key($0.element), b = key($1.element)
                return (a.0, a.1, $0.offset) < (b.0, b.1, $1.offset)
            }
            .map(\.element)
    }

    // MARK: Private

    /// `21:16 IST`, or `Fri 07:30 IST` when that isn't today in `zone`.
    static func timeOnDay(_ instant: Date, in zone: Zone, now: Date) -> String {
        let time = ZoneClock.timeWithAbbreviation(instant, in: zone)
        return isOtherDay(instant, in: zone, now: now)
            ? ZoneClock.local(instant, in: zone).date.weekdayText + " " + time : time
    }

    private static func isOtherDay(_ instant: Date, in zone: Zone, now: Date) -> Bool {
        ZoneClock.local(instant, in: zone).date != ZoneClock.local(now, in: zone).date
    }

    private static func sameZone(_ a: Zone, _ b: Zone) -> Bool {
        a == b || (a.isUTC && b.isUTC)
    }

    /// §5.2 note when the rule decided the target.
    private static func untilNote(_ target: UntilTarget, instant: Date) -> String? {
        let wanted = String(format: "%02d:%02d", target.hour, target.minute)
        let place = "in \(target.zone.cityName) on \(target.date.shortText)"
        let used = ZoneClock.shortName(target.zone, at: instant)
        switch target.resolution {
        case .exact:
            return nil
        case .skipped:
            return "\(wanted) doesn't happen \(place); ends \(ZoneClock.timeWithAbbreviation(instant, in: target.zone)). "
                + "Your scheduler may differ."
        case .repeated:
            let head = "\(wanted) happens twice \(place); "
            switch (target.occurrence, target.used) {
            case (.first, .second): return head + "the first has passed, so this is the second (\(used))."
            case (_, .first): return head + "using the first (\(used)). Your scheduler may differ."
            case (_, .second): return head + "using the second (\(used))."
            }
        }
    }

    private static func epoch(_ date: Date) -> EpochValue {
        EpochValue(seconds: Int64(date.timeIntervalSince1970.rounded(.down)), nanoseconds: 0)
    }
}

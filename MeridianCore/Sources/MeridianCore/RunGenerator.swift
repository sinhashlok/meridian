import Foundation

/// One upcoming run of a wall-clock schedule (cron or a Jobs preset).
public struct ScheduledRun: Equatable, Sendable {
    public let instant: Date
    /// The wall time the schedule asked for, in the schedule's zone.
    public let wallTime: LocalDateTime
    /// `.skipped` or `.repeated` when the gap/overlap rule decided the instant; the UI
    /// then says "Your scheduler may differ" (spec §5.2).
    public let kind: Resolution.Kind
}

/// A time of day a schedule fires at.
struct TimeOfDay: Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int
    let second: Int

    var secondsOfDay: Int { hour * 3600 + minute * 60 + second }

    static func < (a: TimeOfDay, b: TimeOfDay) -> Bool { a.secondsOfDay < b.secondsOfDay }
}

/// Turns "these days, at these times, in this zone" into instants, applying the
/// gap/overlap rule on clock-change days.
enum RunGenerator {
    /// 400 Gregorian years: dates and weekdays repeat exactly after this, so a schedule
    /// with no run inside it never runs.
    static let horizonDays = 146_097

    /// The next `count` runs strictly after `instant`, oldest first. `times` must be sorted.
    /// A skipped time that lands on an instant already used (02:00 → 03:00 when 03:00 is
    /// also scheduled) counts once; a repeated time runs at its first occurrence only.
    static func nextRuns(after instant: Date, in zone: Zone, count: Int, times: [TimeOfDay],
                         lastYear: Int? = nil, matchesDay: (CivilDate) -> Bool) -> [ScheduledRun] {
        guard count > 0, !times.isEmpty else { return [] }
        var runs: [ScheduledRun] = []
        var latest = instant
        // Start a day early: a run on the previous local day can still be in the future
        // relative to the zone's offset changing.
        var day = ZoneClock.local(instant, in: zone).date.adding(days: -1)
        // A matching day's end is the next day's start: kept for when that day matches too.
        var knownStart: (day: CivilDate, start: Date)?

        for _ in 0..<horizonDays {
            if let lastYear, day.year > lastYear { break }
            if matchesDay(day) {
                let start = if let knownStart, knownStart.day == day { knownStart.start }
                            else { ZoneClock.startOfDay(day, in: zone) }
                let next = day.adding(days: 1)
                let end = ZoneClock.startOfDay(next, in: zone)
                knownStart = (next, end)
                // Most days have no clock change: plain arithmetic from local midnight. The
                // day's true end (not 24 h) also catches a change at midnight (Chile).
                let isPlainDay = ZoneClock.transitions(in: zone, from: start, to: end).isEmpty
                for time in times {
                    let wall = LocalDateTime(date: day, hour: time.hour, minute: time.minute)
                    let candidate: Date
                    let kind: Resolution.Kind
                    if isPlainDay {
                        candidate = start.addingTimeInterval(TimeInterval(time.secondsOfDay))
                        kind = .exact
                    } else {
                        let resolved = ZoneClock.resolve(wall, in: zone, occurrence: .first)
                        candidate = resolved.instant.addingTimeInterval(TimeInterval(time.second))
                        kind = resolved.kind
                    }
                    guard candidate > latest else { continue }
                    runs.append(ScheduledRun(instant: candidate, wallTime: wall, kind: kind))
                    latest = candidate
                    if runs.count == count { return runs }
                }
            }
            guard day.year < 9999 else { break }
            day = day.adding(days: 1)
        }
        return runs
    }
}

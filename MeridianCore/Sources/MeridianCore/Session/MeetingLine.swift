import Foundation

/// The Sessions meeting line (spec §4.5, decision AY): the best window from now, in the
/// Planner's counts wording, so a focus block can be planned around it.
public struct MeetingLine: Equatable, Sendable {
    /// `Best compromise in 21 min`, `Best time now`, `No shared window today`.
    public let title: String
    /// `16:00 UTC`, or `Mon 16:00 UTC` when the window isn't today.
    public let time: String?
    /// `3 of 3 awake · Mumbai in stretch`.
    public let counts: String?
    /// Where tapping goes in the Planner (`nil` if no window was found).
    public let start: Date?
    public let day: CivilDate?
    let isToday: Bool

    /// The app card's second line (board Sessions): `16:00 UTC · 3 of 3 awake · …`, or
    /// `Next: Mon 16:00 UTC · …` when the window is on a later day.
    public var detail: String? {
        guard let time, let counts else { return nil }
        return (isToday ? "" : "Next: ") + "\(time) · \(counts)"
    }

    /// The Live Activity's first line (board LiveActivity): `Best compromise in 21 min ·
    /// 16:00 UTC`, or `No shared window today · next Mon 16:00 UTC`; counts go below it.
    public var headline: String {
        guard let time else { return title }
        return title + (isToday ? " · " : " · next ") + time
    }

    /// `nil` with fewer than 2 zones (spec: hidden). `home` is the Planner's reference.
    public static func make(zones: [PlannerZone], home: Zone, now: Date, minutes: Int = 30) -> MeetingLine? {
        guard zones.count >= 2 else { return nil }
        let today = ZoneClock.local(now, in: home).date
        guard let best = OverlapEngine.bestWindow(from: today, home: home, zones: zones, minutes: minutes, notBefore: now)
        else {
            return MeetingLine(title: "No shared window today", time: nil, counts: nil, start: nil, day: nil,
                               isToday: true)
        }

        let start = best.window.interval.start
        let time = ZoneClock.wallTime(start, in: .utc) + " UTC"
        guard best.day == today else {
            return MeetingLine(title: "No shared window today", time: "\(best.day.weekdayText) \(time)",
                               counts: best.countsText, start: start, day: best.day, isToday: false)
        }
        let kind = best.window.isAllWork ? "Best time" : "Best compromise"
        let minutesAway = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return MeetingLine(title: minutesAway <= 0 ? "\(kind) now" : "\(kind) in \(inText(minutes: minutesAway))",
                           time: time, counts: best.countsText, start: start, day: best.day, isToday: true)
    }

    /// `21 min`, `2 h`, `2 h 5 min`.
    private static func inText(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

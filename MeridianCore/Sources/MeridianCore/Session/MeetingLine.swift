import Foundation

/// The Sessions meeting line (spec §4.5, decision AY): the best window from now, in the
/// Planner's counts wording, so a focus block can be planned around it.
public struct MeetingLine: Equatable, Sendable {
    /// `Best compromise in 21 min`, `Best time now`, `No shared window today`.
    public let title: String
    /// `16:00 UTC · 3 of 3 awake · Mumbai in stretch`; `Next: Mon 16:00 UTC · …` when
    /// the best window is on a later day.
    public let detail: String?
    /// Where tapping goes in the Planner (`nil` if no window was found).
    public let start: Date?
    public let day: CivilDate?

    /// `nil` with fewer than 2 zones (spec: hidden). `home` is the Planner's reference.
    public static func make(zones: [PlannerZone], home: Zone, now: Date, minutes: Int = 30) -> MeetingLine? {
        guard zones.count >= 2 else { return nil }
        let today = ZoneClock.local(now, in: home).date
        guard let best = OverlapEngine.bestWindow(from: today, home: home, zones: zones, minutes: minutes, notBefore: now)
        else { return MeetingLine(title: "No shared window today", detail: nil, start: nil, day: nil) }

        let start = best.window.interval.start
        let time = ZoneClock.wallTime(start, in: .utc) + " UTC"
        guard best.day == today else {
            let weekday = best.day.weekdayText
            return MeetingLine(title: "No shared window today", detail: "Next: \(weekday) \(time) · \(best.countsText)",
                               start: start, day: best.day)
        }
        let kind = best.window.isAllWork ? "Best time" : "Best compromise"
        let minutesAway = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return MeetingLine(title: minutesAway <= 0 ? "\(kind) now" : "\(kind) in \(inText(minutes: minutesAway))",
                           detail: "\(time) · \(best.countsText)", start: start, day: best.day)
    }

    /// `21 min`, `2 h`, `2 h 5 min`.
    private static func inText(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}

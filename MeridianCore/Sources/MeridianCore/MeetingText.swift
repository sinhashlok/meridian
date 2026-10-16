import Foundation

/// Copy/Share text for a meeting (spec §4.1). Every time carries its offset.
///
///     Meeting · Thu 15 Oct · 30 min
///     16:00–16:30 UTC
///
///     Mumbai         21:30 IST (UTC+5:30)  late
///     London         17:00 BST (UTC+1)
///     San Francisco  09:00 PDT (UTC−7)
public enum MeetingText {
    public static func make(start: Date, minutes: Int, zones: [PlannerZone], now: Date) -> String {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let header = "Meeting · \(ZoneClock.local(start, in: .utc).date.shortText) · \(minutes) min"
        let range = "\(ZoneClock.wallTime(start, in: .utc))–\(ZoneClock.wallTime(end, in: .utc)) UTC"

        let labels = zones.map { ZoneClock.copyText(start, in: $0.zone) }
        let tags = tags(start: start, minutes: minutes, zones: zones)
        let nameWidth = (zones.map(\.name.count).max() ?? 0) + 2
        let labelWidth = (labels.map(\.count).max() ?? 0) + 2
        let rows = zones.indices.map { index in
            let name = padded(zones[index].name, to: nameWidth)
            guard let tag = tags[index] else { return name + labels[index] }
            return name + padded(labels[index], to: labelWidth) + tag
        }

        // Spec §5.3: say when a zone changes its clocks between now and the meeting.
        var notes: [String] = []
        for zone in zones {
            for change in ZoneClock.transitions(in: zone.zone, from: now, to: start) where change.instant > now {
                let note = "\(zone.name) changes clocks on \(ZoneClock.local(change.instant, in: zone.zone).date.shortText)"
                if !notes.contains(note) { notes.append(note) }
            }
        }

        var lines = [header, range, ""] + rows
        if !notes.isEmpty { lines += [""] + notes }
        return lines.joined(separator: "\n")
    }

    /// Per zone: `early` / `late` (stretch before / after work), `asleep`, `weekend`, or
    /// `nil` in work hours (decision L).
    public static func tags(start: Date, minutes: Int, zones: [PlannerZone]) -> [String?] {
        let window = OverlapEngine.window(starting: start, minutes: minutes, zones: zones)
        return zip(zones, window.kinds).map { zone, kind -> String? in
            let local = ZoneClock.local(start, in: zone.zone)
            switch kind {
            case .work: return nil
            case .sleep: return "asleep"
            case .stretch:
                if !zone.isWorkDay(local.date) { return "weekend" }
                return ClockTime(local.hour, local.minute) < zone.workStart ? "early" : "late"
            }
        }
    }

    /// Pads by characters, so `−` and accented names count as one column each.
    private static func padded(_ text: String, to width: Int) -> String {
        text + String(repeating: " ", count: max(0, width - text.count))
    }
}

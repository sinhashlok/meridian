import Foundation

/// One zone in Upcoming clock changes: its next change, or `No clock changes`.
public struct ClockChangeCard: Equatable, Sendable {
    public let name: String
    /// `nil` for zones without a change in the next two years.
    public let instant: Date?
    /// `Back 1 hour`, `Forward 30 min`, `No clock changes`.
    public let headline: String
    /// The offset after the change (`UTC+0`), or the current one.
    public let offset: String
    /// `Sun 25 Oct 2026 · 02:00 BST → 01:00 GMT`, or `IST all year`.
    public let detail: String
    /// `06:30 IST on this phone · in 9 days`.
    public let phone: String?
}

/// The Clocks banner shown when "Warn before clocks change" is on.
public struct ClockChangeWarning: Equatable, Sendable {
    public let title: String
    public let detail: String
}

extension Transition {
    /// Wall clock just before the change and what it jumps to: (`02:00`, `01:00`) for
    /// London going back.
    var wallTimes: (from: String, to: String) {
        (ZoneClock.wallTime(instant.addingTimeInterval(TimeInterval(before.offsetSeconds)), in: .utc),
         ZoneClock.wallTime(instant.addingTimeInterval(TimeInterval(after.offsetSeconds)), in: .utc))
    }

    var shiftSeconds: Int { after.offsetSeconds - before.offsetSeconds }

    /// `back 1 hour`, `forward 30 min`, `back 2 hours`.
    var directionText: String {
        let minutes = abs(shiftSeconds) / 60
        let amount = minutes % 60 != 0 ? "\(minutes) min" : minutes == 60 ? "1 hour" : "\(minutes / 60) hours"
        return (shiftSeconds < 0 ? "back " : "forward ") + amount
    }
}

extension ZoneClock {
    /// Upcoming clock changes (board ClockChanges): one card per zone with its next change,
    /// soonest first, then zones without changes. Duplicate zones keep their first name.
    public static func changeCards(for zones: [(zone: Zone, name: String)], now: Date, device: Zone) -> [ClockChangeCard] {
        var seen = Set<Zone>()
        let cards = zones.filter { seen.insert($0.zone).inserted }.map { zone, name -> ClockChangeCard in
            guard let change = nextChange(in: zone, after: now) else {
                let state = state(zone, at: now)
                return ClockChangeCard(name: name, instant: nil, headline: "No clock changes",
                                       offset: zone.isUTC ? "UTC" : offsetLabel(seconds: state.offsetSeconds),
                                       detail: "\(state.shortName) all year", phone: nil)
            }
            let (from, to) = change.wallTimes
            let date = local(change.instant, in: zone).date
            let direction = change.directionText
            return ClockChangeCard(
                name: name, instant: change.instant,
                headline: direction.prefix(1).uppercased() + direction.dropFirst(),
                offset: offsetLabel(seconds: change.after.offsetSeconds),
                detail: "\(date.shortText) \(date.year) · \(from) \(change.before.shortName) → \(to) \(change.after.shortName)",
                phone: "\(wallTime(change.instant, in: device)) \(shortName(device, at: change.instant)) on this phone · "
                    + daysUntil(change.instant, in: zone, now: now))
        }
        return cards.filter { $0.instant != nil }.sorted { $0.instant! < $1.instant! } + cards.filter { $0.instant == nil }
    }

    /// The Clocks banner for the soonest change within 14 days (the DST badge window):
    /// `London clocks go back 1 hour on Sun 25 Oct` · `In 9 days. London becomes GMT
    /// (UTC+0), 5h 30m behind you instead of 4h 30m.` "You" is the home zone.
    public static func changeWarning(for zones: [(zone: Zone, name: String)], home: Zone, now: Date) -> ClockChangeWarning? {
        let soonest = zones.compactMap { zone, name in nextChange(in: zone, after: now).map { (zone, name, $0) } }
            .min { $0.2.instant < $1.2.instant }
        guard let (zone, name, change) = soonest,
              local(change.instant, in: zone).date.days(since: local(now, in: zone).date) <= 14 else { return nil }

        let when = daysUntil(change.instant, in: zone, now: now)
        var detail = when.prefix(1).uppercased() + when.dropFirst() + ". \(name) becomes \(change.after.label)"
        let before = change.before.offsetSeconds - state(home, at: change.instant.addingTimeInterval(-1)).offsetSeconds
        let after = change.after.offsetSeconds - state(home, at: change.instant).offsetSeconds
        if zone != home, before != after {
            detail += ", \(relationText(after, to: "you")) instead of \(previousRelationText(before, now: after))"
        }
        let date = local(change.instant, in: zone).date
        return ClockChangeWarning(title: "\(name) clocks go \(change.directionText) on \(date.shortText)",
                                  detail: detail + ".")
    }

    // MARK: Shared wording

    /// `5h 30m`, `1h`, `30m` with no sign.
    static func amountText(_ seconds: Int) -> String {
        String(durationText(seconds: abs(seconds)).dropFirst())
    }

    /// `5h 30m behind Mumbai`, `1h ahead of you`, `level with UTC`.
    static func relationText(_ seconds: Int, to name: String) -> String {
        if seconds == 0 { return "level with \(name)" }
        return seconds < 0 ? "\(amountText(seconds)) behind \(name)" : "\(amountText(seconds)) ahead of \(name)"
    }

    /// What the difference used to be: just the amount when the side didn't change
    /// (`4h 30m`), else `1h ahead`, `1h behind` or `level`.
    static func previousRelationText(_ seconds: Int, now current: Int) -> String {
        if seconds != 0, seconds.signum() == current.signum() { return amountText(seconds) }
        if seconds == 0 { return "level" }
        return "\(amountText(seconds)) " + (seconds < 0 ? "behind" : "ahead")
    }

    // MARK: Private

    private static func nextChange(in zone: Zone, after now: Date) -> Transition? {
        transitions(in: zone, from: now.addingTimeInterval(1), to: now.addingTimeInterval(2 * 366 * 86_400)).first
    }

    /// `today`, `tomorrow`, `in 9 days`: calendar days in the changing zone (decision M).
    private static func daysUntil(_ instant: Date, in zone: Zone, now: Date) -> String {
        switch local(instant, in: zone).date.days(since: local(now, in: zone).date) {
        case 0: "today"
        case 1: "tomorrow"
        case let days: "in \(days) days"
        }
    }
}

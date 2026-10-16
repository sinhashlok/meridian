import Foundation

/// The Planner's banner for the viewed day: `No hour works for all 3 cities` with the reason.
public struct PlannerBanner: Equatable, Sendable {
    public let title: String
    public let detail: String?
}

/// A dashed fault line where a non-reference zone changes clocks: `London −1h, Sun 25 Oct`.
public struct FaultLine: Equatable, Sendable {
    public let zoneName: String
    public let instant: Date
    public let chip: String
}

/// The reference zone's own clock change, which makes the axis 23 or 25 hours long.
public struct ReferenceChange: Equatable, Sendable {
    public let instant: Date
    /// Over the axis: `01 BST · 01 GMT` (repeated hour) or `01–02 skipped`.
    public let label: String
    /// Both occurrences of the repeated hour, shaded across the rows; `nil` when skipped.
    public let repeated: DateInterval?
    public let note: String
}

extension PlannerDay {
    /// About the viewed day (the best window may be on a later one): `Weekend in all 3
    /// cities`, or `No hour works for all 3 cities` with the first reason found, a zone
    /// with no work hours that day or a pair whose work hours never meet.
    public var banner: PlannerBanner? {
        let working = rows.map { row in row.segments.filter { $0.kind == .work }.map(\.interval) }
        if working.allSatisfy(\.isEmpty) {
            return PlannerBanner(title: "Weekend in all \(rows.count) cities", detail: nil)
        }
        guard overlap(of: working) == nil else { return nil }

        var detail: String?
        if let resting = rows.indices.first(where: { working[$0].isEmpty }) {
            detail = "\(rows[resting].zone.name) is on its weekend."
        } else {
            pairs: for a in rows.indices {
                for b in rows.indices where b > a && overlap(of: [working[a], working[b]]) == nil {
                    detail = "\(rows[a].zone.name) and \(rows[b].zone.name) working hours never meet."
                    break pairs
                }
            }
        }
        return PlannerBanner(title: "No hour works for all \(rows.count) cities", detail: detail)
    }

    /// `IST · Thu 15`; the reference's name when it changes clocks that day (`London · Sun 25`).
    public func headerTitle(reference: Zone, referenceName: String) -> String {
        let changes = !ZoneClock.transitions(in: reference, from: axis.start, to: axis.end).isEmpty
        let name = changes ? referenceName : ZoneClock.shortName(reference, at: axis.start)
        return "\(name) · \(date.weekdayText) \(date.day)"
    }

    /// Under each row name. Today: the zone's time now (`21:02 IST`). Another day, or any
    /// day with a clock change: the offset (`IST · +5:30`) or the change (`BST → GMT`).
    public func caption(for zone: PlannerZone, now: Date) -> String {
        let changes = ZoneClock.transitions(in: zone.zone, from: axis.start, to: axis.end)
        if let first = changes.first, let last = changes.last {
            return "\(first.before.shortName) → \(last.after.shortName)"
        }
        if axis.contains(now), transitions.isEmpty {
            return ZoneClock.wallTime(now, in: zone.zone) + " " + ZoneClock.shortName(zone.zone, at: now)
        }
        let state = ZoneClock.state(zone.zone, at: axis.start)
        guard let abbreviation = state.abbreviation, abbreviation != "UTC" else { return state.shortName }
        let offset = ZoneClock.offsetLabel(seconds: state.offsetSeconds).dropFirst(3)   // drop "UTC"
        return "\(abbreviation) · \(offset)"
    }

    /// Clock changes of zones other than the reference (whose own change is the axis length).
    public func faultLines(reference: Zone) -> [FaultLine] {
        faultTransitions(reference: reference).map { zone, change in
            let shift = change.after.offsetSeconds - change.before.offsetSeconds
            let date = ZoneClock.local(change.instant, in: zone.zone).date
            return FaultLine(zoneName: zone.name, instant: change.instant,
                             chip: "\(zone.name) \(ZoneClock.durationText(seconds: shift)), \(date.shortText)")
        }
    }

    /// `At 01:00 UTC London goes from BST to GMT. Its day moves 1h later on this timeline:
    /// London is now 5h 30m behind Mumbai, not 4h 30m. San Francisco follows on Sun 1 Nov.`
    public func faultLineNote(reference: Zone, referenceName: String) -> String? {
        let faults = faultTransitions(reference: reference)
        guard !faults.isEmpty else { return nil }
        var sentences: [String] = []
        for (zone, change) in faults {
            sentences.append("At \(ZoneClock.wallTime(change.instant, in: .utc)) UTC \(zone.name) goes from "
                             + "\(change.before.shortName) to \(change.after.shortName).")
            let before = change.before.offsetSeconds - ZoneClock.state(reference, at: change.instant.addingTimeInterval(-1)).offsetSeconds
            let after = change.after.offsetSeconds - ZoneClock.state(reference, at: change.instant).offsetSeconds
            guard before != after else { continue }
            let shift = change.after.offsetSeconds - change.before.offsetSeconds
            let old = before.signum() == after.signum() ? Self.amount(before) : Self.relation(before, to: nil)
            sentences[sentences.count - 1] += " Its day moves \(Self.amount(shift)) \(shift < 0 ? "later" : "earlier") on "
                + "this timeline: \(zone.name) is now \(Self.relation(after, to: referenceName)), not \(old)."
        }

        // Zones that change soon after, so the reader knows the gap moves again.
        let changingToday = Set(faults.map(\.0.zone)).union([reference])
        var following: [(date: CivilDate, names: [String])] = []
        var seen = Set<Zone>()
        for row in rows where !changingToday.contains(row.zone.zone) && seen.insert(row.zone.zone).inserted {
            let horizon = axis.end.addingTimeInterval(14 * 86_400)
            guard let next = ZoneClock.transitions(in: row.zone.zone, from: axis.end, to: horizon).first else { continue }
            let date = ZoneClock.local(next.instant, in: row.zone.zone).date
            if let index = following.firstIndex(where: { $0.date == date }) {
                following[index].names.append(row.zone.name)
            } else {
                following.append((date, [row.zone.name]))
            }
        }
        for group in following {
            let verb = group.names.count == 1 ? "follows" : "follow"
            sentences.append("\(group.names.joined(separator: " and ")) \(verb) on \(group.date.shortText).")
        }
        return sentences.joined(separator: " ")
    }

    /// The reference zone's clock change on this day, if any (spec §5.3: 23/25-hour axis
    /// with a skipped/repeated-hour marker).
    public func referenceChange(reference: Zone, referenceName: String) -> ReferenceChange? {
        guard let change = ZoneClock.transitions(in: reference, from: axis.start, to: axis.end).first else { return nil }
        let shift = change.after.offsetSeconds - change.before.offsetSeconds
        // Wall clock just before the change, and what it jumps to.
        let from = ZoneClock.wallTime(change.instant.addingTimeInterval(TimeInterval(change.before.offsetSeconds)), in: .utc)
        let to = ZoneClock.wallTime(change.instant.addingTimeInterval(TimeInterval(change.after.offsetSeconds)), in: .utc)
        let length = "The axis is \(hoursText) hours long, and every row is placed by real time."

        if shift < 0 {
            let hour = String(to.prefix(2))
            return ReferenceChange(
                instant: change.instant,
                label: "\(hour) \(change.before.shortName) · \(hour) \(change.after.shortName)",
                repeated: DateInterval(start: change.instant.addingTimeInterval(TimeInterval(shift)),
                                       end: change.instant.addingTimeInterval(TimeInterval(-shift))),
                note: "\(referenceName) clocks go back at \(from) \(change.before.shortName), so \(to)–\(from) happens "
                    + "twice. \(length)")
        }
        return ReferenceChange(
            instant: change.instant,
            label: "\(from.prefix(2))–\(to.prefix(2)) skipped",
            repeated: nil,
            note: "\(referenceName) clocks go forward at \(from) \(change.before.shortName), so \(from)–\(to) is "
                + "skipped. \(length)")
    }

    // MARK: Private

    private func faultTransitions(reference: Zone) -> [(PlannerZone, Transition)] {
        var seen = Set<Zone>()
        return rows.filter { $0.zone.zone != reference && seen.insert($0.zone.zone).inserted }.flatMap { row in
            ZoneClock.transitions(in: row.zone.zone, from: axis.start, to: axis.end).map { (row.zone, $0) }
        }
    }

    /// A moment every list of intervals shares, or `nil`.
    private func overlap(of lists: [[DateInterval]]) -> DateInterval? {
        guard var common = lists.first else { return nil }
        for list in lists.dropFirst() {
            common = common.flatMap { a in list.compactMap { b in a.intersection(with: b).flatMap { $0.duration > 0 ? $0 : nil } } }
        }
        return common.first
    }

    /// `25`, `23`, `24.5`.
    var hoursText: String {
        let hours = axis.duration / 3600
        return hours == hours.rounded() ? "\(Int(hours))" : String(format: "%.1f", hours)
    }

    /// `5h 30m`, `1h`, `30m` with no sign.
    private static func amount(_ seconds: Int) -> String {
        String(ZoneClock.durationText(seconds: abs(seconds)).dropFirst())
    }

    /// `5h 30m behind Mumbai`, `1h ahead`, `level with UTC`.
    private static func relation(_ seconds: Int, to name: String?) -> String {
        let suffix = name.map { " \($0)" } ?? ""
        if seconds == 0 { return name.map { "level with \($0)" } ?? "level" }
        return seconds < 0 ? "\(amount(seconds)) behind\(suffix)" : "\(amount(seconds)) ahead" + (name.map { " of \($0)" } ?? "")
    }
}

extension ZoneState {
    /// `BST`, or the offset label (`UTC+5:45`) for zones without a curated abbreviation.
    var shortName: String { abbreviation ?? label }
}

extension ZoneClock {
    /// `IST`, `UTC+5:45`, `UTC`.
    static func shortName(_ zone: Zone, at instant: Date) -> String {
        state(zone, at: instant).shortName
    }
}

extension Scrubber {
    /// The bubble over the scrubber: `Thu 21:30 IST`; while scrubbing `Thu 20:30 IST · 15:00 UTC`.
    public static func bubbleText(_ instant: Date, reference: Zone, withUTC: Bool) -> String {
        let day = ZoneClock.local(instant, in: reference).date.weekdayText
        let text = "\(day) \(ZoneClock.wallTime(instant, in: reference)) \(ZoneClock.shortName(reference, at: instant))"
        guard withUTC, !reference.isUTC else { return text }
        return text + " · \(ZoneClock.wallTime(instant, in: .utc)) UTC"
    }
}

extension MeetingText {
    /// `16:00–16:30 UTC`, or `Mon 16:00–16:30 UTC` with the UTC weekday (decision N).
    public static func utcRange(start: Date, minutes: Int, showsDay: Bool = false) -> String {
        let end = start.addingTimeInterval(TimeInterval(minutes * 60))
        let range = "\(ZoneClock.wallTime(start, in: .utc))–\(ZoneClock.wallTime(end, in: .utc)) UTC"
        return showsDay ? "\(ZoneClock.local(start, in: .utc).date.weekdayText) \(range)" : range
    }

    /// `Thu 15 Oct · 30 min` (the UTC date, like the copy text header).
    public static func summary(start: Date, minutes: Int) -> String {
        "\(ZoneClock.local(start, in: .utc).date.shortText) · \(minutes) min"
    }
}

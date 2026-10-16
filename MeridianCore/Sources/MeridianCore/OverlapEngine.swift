import Foundation

/// A zone on the Planner with its working pattern (spec §4.1, §7 `Zone`).
public struct PlannerZone: Hashable, Sendable {
    public let zone: Zone
    /// Display name used in counts wording ("Mumbai", "SF").
    public let name: String
    public let workStart: ClockTime
    public let workEnd: ClockTime
    /// ISO weekdays (Monday = 1 … Sunday = 7). Other days have no work hours.
    public let workDays: Set<Int>
    /// Stretch hours before work and after it (decision G: 2 h and 4 h → 07–09, 18–22).
    public let stretchBeforeMinutes: Int
    public let stretchAfterMinutes: Int

    /// Work hours must start and end on the same local day (decision G).
    public init(zone: Zone, name: String, workStart: ClockTime = ClockTime(9, 0), workEnd: ClockTime = ClockTime(18, 0),
                workDays: Set<Int> = [1, 2, 3, 4, 5], stretchBeforeMinutes: Int = 120, stretchAfterMinutes: Int = 240) {
        precondition(workStart < workEnd, "work hours must start before they end, on the same day")
        self.zone = zone
        self.name = name
        self.workStart = workStart
        self.workEnd = workEnd
        self.workDays = workDays
        self.stretchBeforeMinutes = stretchBeforeMinutes
        self.stretchAfterMinutes = stretchAfterMinutes
    }

    /// Work, stretch or sleep at `instant`, from this zone's wall clock that day.
    func kind(at instant: Date) -> HourKind {
        let local = ZoneClock.local(instant, in: zone)
        let minute = local.hour * 60 + local.minute
        let start = workStart.hour * 60 + workStart.minute, end = workEnd.hour * 60 + workEnd.minute
        if isWorkDay(local.date), (start..<end).contains(minute) { return .work }
        if (max(0, start - stretchBeforeMinutes)..<min(24 * 60, end + stretchAfterMinutes)).contains(minute) {
            return .stretch                             // on weekends this covers the work hours too
        }
        return .sleep
    }

    func isWorkDay(_ date: CivilDate) -> Bool { workDays.contains(date.isoWeekday) }
}

/// Planner hour types. Drawn by bar height first (work 26pt, stretch 16pt, sleep 4pt).
/// Ordered best to worst, so the worst kind over a window is the `max`.
public enum HourKind: Int, Comparable, Sendable {
    case work, stretch, sleep

    public static func < (a: HourKind, b: HourKind) -> Bool { a.rawValue < b.rawValue }
}

/// A run of one hour kind on a Planner row, in real UTC instants.
public struct Segment: Hashable, Sendable {
    public let interval: DateInterval
    public let kind: HourKind
}

public struct PlannerRow: Hashable, Sendable {
    public let zone: PlannerZone
    /// Consecutive segments that exactly cover the day's axis.
    public let segments: [Segment]
}

/// A clock change on the axis, for the skipped/repeated-hour marker.
public struct ZoneTransition: Equatable, Sendable {
    public let zoneName: String
    public let transition: Transition
}

/// One Planner day: the home zone's local day at its true length (23, 24 or 25 h).
public struct PlannerDay: Sendable {
    public let date: CivilDate
    public let axis: DateInterval
    public let rows: [PlannerRow]
    public let transitions: [ZoneTransition]
}

/// A candidate meeting and how each zone sits in it (worst kind over the window).
public struct MeetingWindow: Equatable, Sendable {
    public let interval: DateInterval
    /// Per zone, in the order given.
    public let kinds: [HourKind]
    public let names: [String]

    public var isAllWork: Bool { kinds.allSatisfy { $0 == .work } }

    /// `3 of 3 in work hours`, or `3 of 3 awake · Mumbai in stretch`, or
    /// `2 of 3 awake · SF asleep` (spec §4.1 counts wording, decision G).
    public var countsText: String {
        if isAllWork { return "\(kinds.count) of \(kinds.count) in work hours" }
        let awake = kinds.filter { $0 != .sleep }.count
        var parts = ["\(awake) of \(kinds.count) awake"]
        let stretch = names(where: .stretch), asleep = names(where: .sleep)
        if !stretch.isEmpty { parts.append(stretch.joined(separator: ", ") + " in stretch") }
        if !asleep.isEmpty { parts.append(asleep.joined(separator: ", ") + " asleep") }
        return parts.joined(separator: " · ")
    }

    private func names(where kind: HourKind) -> [String] {
        zip(names, kinds).filter { $0.1 == kind }.map(\.0)
    }

    /// Decision D: fewest asleep, then fewest in stretch. All-in-work scores (0, 0).
    var score: (asleep: Int, stretch: Int) {
        (kinds.filter { $0 == .sleep }.count, kinds.filter { $0 == .stretch }.count)
    }
}

/// The BestWindowChip's answer.
public struct BestWindow: Equatable, Sendable {
    /// The home-zone day the window is on (later than asked if weekends were skipped).
    public let day: CivilDate
    public let window: MeetingWindow
    /// Stretches where every zone is in work hours that day (empty if none).
    public let allWorkRanges: [DateInterval]
    public let skippedWeekend: Bool
    let zoneCount: Int

    public var countsText: String { window.countsText }

    /// `No hour works for all 3 cities` when there is no all-work overlap (then the
    /// window is the "Best compromise").
    public var noOverlapBanner: String? {
        allWorkRanges.isEmpty ? "No hour works for all \(zoneCount) cities" : nil
    }

    /// `Skipping the weekend · Mon 26 Oct`.
    public var skipNote: String? {
        skippedWeekend ? "Skipping the weekend · \(day.shortText)" : nil
    }
}

/// Planner maths: rows by real UTC instants on the home zone's day, and the best window.
public enum OverlapEngine {
    /// The Planner grid and the scrubber snap.
    public static let slotMinutes = 15

    /// The home zone's `date` at true length, with each zone's work/stretch/sleep
    /// segments and any clock changes inside it.
    public static func day(_ date: CivilDate, home: Zone, zones: [PlannerZone]) -> PlannerDay {
        let axis = axis(of: date, home: home)
        let slots = slotStarts(in: axis)
        let rows = zones.map { zone in
            var segments: [Segment] = []
            for start in slots {
                let kind = zone.kind(at: start)
                let end = min(start.addingTimeInterval(TimeInterval(slotMinutes * 60)), axis.end)
                if let last = segments.last, last.kind == kind {
                    segments[segments.count - 1] = Segment(interval: DateInterval(start: last.interval.start, end: end), kind: kind)
                } else {
                    segments.append(Segment(interval: DateInterval(start: start, end: end), kind: kind))
                }
            }
            return PlannerRow(zone: zone, segments: segments)
        }
        let transitions = zones.flatMap { zone in
            ZoneClock.transitions(in: zone.zone, from: axis.start, to: axis.end)
                .map { ZoneTransition(zoneName: zone.name, transition: $0) }
        }
        return PlannerDay(date: date, axis: axis, rows: rows, transitions: transitions)
    }

    /// How each zone sits in the meeting `[start, start + minutes)`.
    public static func window(starting start: Date, minutes: Int, zones: [PlannerZone]) -> MeetingWindow {
        let interval = DateInterval(start: start, duration: TimeInterval(minutes * 60))
        let slots = stride(from: 0, to: minutes, by: slotMinutes).map { start.addingTimeInterval(TimeInterval($0 * 60)) }
        let kinds = zones.map { zone in slots.map(zone.kind(at:)).max() ?? .sleep }
        return MeetingWindow(interval: interval, kinds: kinds, names: zones.map(\.name))
    }

    /// The best `minutes`-long window on `date` (home zone's day), or a later day if
    /// weekends are skipped (decision E). Ranking (decision D): fewest asleep, then
    /// fewest in stretch, then soonest. Windows start on the 15-minute grid and stay
    /// inside the day. `nil` if nothing qualifies within `searchDays`.
    public static func bestWindow(from date: CivilDate, home: Zone, zones: [PlannerZone], minutes: Int = 30,
                                  notBefore: Date? = nil, searchDays: Int = 14) -> BestWindow? {
        precondition(minutes > 0 && minutes % slotMinutes == 0, "meeting length must be a multiple of 15 minutes")
        guard !zones.isEmpty else { return nil }
        var skipped = false

        for offset in 0..<searchDays {
            let day = date.adding(days: offset)
            let axis = axis(of: day, home: home)
            let slots = slotStarts(in: axis)

            // Decision E: skip the day only if every slot has some zone on its weekend.
            let hasWorkdaySlot = slots.contains { slot in
                zones.allSatisfy { $0.isWorkDay(ZoneClock.local(slot, in: $0.zone).date) }
            }
            guard hasWorkdaySlot else { skipped = true; continue }

            let lastStart = axis.end.addingTimeInterval(-TimeInterval(minutes * 60))
            let candidates = slots
                .filter { $0 <= lastStart && $0 >= (notBefore ?? .distantPast) }
                .map { window(starting: $0, minutes: minutes, zones: zones) }
            // `min(by:)` keeps the first of equal scores, so ties go to the soonest.
            guard let best = candidates.min(by: { $0.score < $1.score }) else { continue }

            return BestWindow(day: day, window: best, allWorkRanges: allWorkRanges(slots: slots, axis: axis, zones: zones),
                              skippedWeekend: skipped, zoneCount: zones.count)
        }
        return nil
    }

    // MARK: Private

    private static func axis(of date: CivilDate, home: Zone) -> DateInterval {
        DateInterval(start: ZoneClock.startOfDay(date, in: home), end: ZoneClock.startOfDay(date.adding(days: 1), in: home))
    }

    private static func slotStarts(in axis: DateInterval) -> [Date] {
        stride(from: 0, to: axis.duration, by: TimeInterval(slotMinutes * 60)).map { axis.start.addingTimeInterval($0) }
    }

    /// Merged stretches of slots where every zone is in work hours.
    private static func allWorkRanges(slots: [Date], axis: DateInterval, zones: [PlannerZone]) -> [DateInterval] {
        var ranges: [DateInterval] = []
        for start in slots where zones.allSatisfy({ $0.kind(at: start) == .work }) {
            let end = min(start.addingTimeInterval(TimeInterval(slotMinutes * 60)), axis.end)
            if let last = ranges.last, last.end == start {
                ranges[ranges.count - 1] = DateInterval(start: last.start, end: end)
            } else {
                ranges.append(DateInterval(start: start, end: end))
            }
        }
        return ranges
    }
}

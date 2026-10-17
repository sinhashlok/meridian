import Foundation

/// The small clock widget and the UTC Lock Screen accessory (decision BT).
public struct ClockWidgetText: Equatable, Sendable {
    public struct Home: Equatable, Sendable {
        /// `Mumbai`.
        public let name: String
        /// `21:02`.
        public let time: String
        /// `IST (UTC+5:30)`.
        public let label: String
        /// `DST in 10d` from 14 days before a change (the Clocks badge).
        public let dstBadge: String?
    }

    /// `15:32`.
    public let utcTime: String
    /// `Thu 15 Oct`: the UTC date.
    public let utcDate: String
    /// `nil` without zones, or when home is UTC (the widget already shows it).
    public let home: Home?
}

/// The medium Planner widget (board WidgetFull, decision BU): the home zone's day.
public struct PlannerWidgetText: Equatable, Sendable {
    /// A run of one hour kind, as fractions (0…1) of the home zone's day.
    public struct Bar: Equatable, Sendable {
        public let start: Double
        public let end: Double
        public let kind: HourKind
    }

    public struct Row: Equatable, Sendable {
        public let name: String
        /// The zone's wall time now: `16:32`.
        public let time: String
        public let isHome: Bool
        /// The zone changes clocks during the home day (short `DST` tag, spec §5.3).
        public let changesClocks: Bool
        public let bars: [Bar]
    }

    /// Home first, at most 3.
    public let rows: [Row]
    /// Where the now-line goes (0…1).
    public let now: Double
    /// `Best compromise`, `Best time`, or `No shared window` when none is found.
    public let bestTitle: String
    /// `16:00–16:30 UTC`; `Mon 16:00–16:30 UTC` on a later day.
    public let bestTime: String?
    /// `3 of 3 awake · Mumbai in stretch`.
    public let counts: String?
}

/// One job on the Jobs widgets and the Next job accessory (boards JobsWidgetFull,
/// JobsWidgetLarge, JobsLockWidgets).
public struct JobWidgetRow: Equatable, Sendable, Identifiable {
    public struct Child: Equatable, Sendable {
        /// `07:50`: expected after the next run, in the shown zone.
        public let time: String
        /// `+0:20`.
        public let offset: String
        public let name: String
    }

    public let id: UUID
    public let title: String
    /// `nil` today, `Fri` within a week, else `1 Nov` (in the shown zone).
    public let day: String?
    /// `21:30`.
    public let time: String
    /// Small and medium: `Every 4 hours · UTC`, `Daily · 02:00 UTC · 4 children`,
    /// `Monthly · 01:00 New York · DST`.
    public let shortLine: String
    /// Large: `Every 4 hours · from 00:00 UTC`, `Daily · 02:00 UTC` (children are listed).
    public let line: String
    /// `in 28 min`, `in 10h 28m`, `in 16 days`.
    public let countdown: String
    /// Under 24 hours: accent and `.widgetAccentable()` (decision BV).
    public let isSoon: Bool
    /// The circular accessory: `28m`, `10h`, `16d`.
    public let compactCountdown: String
    public let children: [Child]
}

public struct JobsWidgetText: Equatable, Sendable {
    /// `IST`, or `UTC` in UTC mode (decision BX).
    public let zoneName: String
    /// Soonest first; paused and never-running jobs are left out.
    public let rows: [JobWidgetRow]
}

/// Wording for the Home Screen widgets and Lock Screen accessories (spec §6). Every time
/// is worked out from the snapshot and `now`, so a timeline entry is just a date.
public enum WidgetText {
    public static func clock(_ snapshot: WidgetSnapshot, now: Date) -> ClockWidgetText {
        let home = snapshot.home.flatMap { saved in Zone(saved.ianaID).map { (zone: $0, name: saved.name) } }
        return ClockWidgetText(
            utcTime: ZoneClock.wallTime(now, in: .utc),
            utcDate: ZoneClock.local(now, in: .utc).date.shortText,
            home: home.flatMap { home in
                home.zone.isUTC ? nil : ClockWidgetText.Home(
                    name: home.name, time: ZoneClock.wallTime(now, in: home.zone),
                    label: ZoneClock.label(home.zone, at: now), dstBadge: ZoneClock.dstBadgeText(home.zone, now: now))
            })
    }

    /// `nil` with fewer than 2 zones (the widget asks for another zone).
    public static func planner(_ snapshot: WidgetSnapshot, now: Date) -> PlannerWidgetText? {
        let zones = snapshot.plannerZones
        guard zones.count >= 2 else { return nil }
        let home = zones[0].zone
        let today = ZoneClock.local(now, in: home).date
        let shown = Array(zones.prefix(3))
        let day = OverlapEngine.day(today, home: home, zones: shown)
        let axis = day.axis
        func fraction(_ instant: Date) -> Double { instant.timeIntervalSince(axis.start) / axis.duration }

        let rows = day.rows.enumerated().map { index, row in
            PlannerWidgetText.Row(
                name: row.zone.name, time: ZoneClock.wallTime(now, in: row.zone.zone), isHome: index == 0,
                changesClocks: !ZoneClock.transitions(in: row.zone.zone, from: axis.start, to: axis.end).isEmpty,
                bars: row.segments.map { .init(start: fraction($0.interval.start), end: fraction($0.interval.end),
                                               kind: $0.kind) })
        }

        // The best window is over every Planner zone, like the app, not only the rows shown.
        guard let best = OverlapEngine.bestWindow(from: today, home: home, zones: zones, notBefore: now) else {
            return PlannerWidgetText(rows: rows, now: fraction(now), bestTitle: "No shared window", bestTime: nil,
                                     counts: nil)
        }
        let window = best.window
        return PlannerWidgetText(
            rows: rows, now: fraction(now),
            bestTitle: window.isAllWork ? "Best time" : "Best compromise",
            bestTime: MeetingText.utcRange(start: window.interval.start, minutes: Int(window.interval.duration / 60),
                                           showsDay: best.day != today),
            counts: best.countsText)
    }

    /// Times follow the UTC pill: the phone's zone, or UTC in UTC mode.
    public static func jobs(_ snapshot: WidgetSnapshot, now: Date, device: Zone, limit: Int = 5) -> JobsWidgetText {
        let display = snapshot.isUTCMode ? Zone.utc : device
        let today = ZoneClock.local(now, in: display).date
        let upcoming = snapshot.jobs
            .filter { !$0.isPaused }
            .compactMap { job in job.nextRuns(after: now, count: 1).first.map { (job: job, run: $0.instant) } }
            .sorted { $0.run < $1.run }
            .prefix(limit)

        let rows = upcoming.map { job, run in
            let local = ZoneClock.local(run, in: display)
            let days = local.date.days(since: today)
            let countdown = JobText.countdown(to: run, now: now)
            let dst = JobText.row(job, now: now, display: display, device: device).dstBadge == nil ? "" : " · DST"
            let children = job.children.count
            return JobWidgetRow(
                id: job.id, title: job.title,
                day: days == 0 ? nil : days < 7 ? local.date.weekdayText : local.date.dayMonthText,
                time: ZoneClock.wallTime(run, in: display),
                shortLine: scheduleLine(job, short: true)
                    + (children == 0 ? "" : " · \(children) \(children == 1 ? "child" : "children")") + dst,
                line: scheduleLine(job, short: false) + dst,
                countdown: countdown.text, isSoon: countdown.isSoon,
                compactCountdown: compactCountdown(to: run, now: now),
                children: job.children.map { child in
                    .init(time: ZoneClock.wallTime(run + TimeInterval(child.offsetMinutes * 60), in: display),
                          offset: JobText.offsetText(child.offsetMinutes), name: child.name)
                })
        }
        return JobsWidgetText(zoneName: ZoneClock.shortName(display, at: now), rows: rows)
    }

    /// `UTC 15:32`.
    public static func utcInline(now: Date) -> String { "UTC " + ZoneClock.wallTime(now, in: .utc) }

    /// `Next job 21:30`, `Next job Fri 07:30`, `No upcoming jobs`.
    public static func nextJobInline(_ jobs: JobsWidgetText) -> String {
        guard let row = jobs.rows.first else { return "No upcoming jobs" }
        return "Next job " + (row.day.map { $0 + " " } ?? "") + row.time
    }

    // MARK: Private

    /// The Jobs list line, shortened where the widget shows the same thing elsewhere: the
    /// date column already gives a monthly job's day; small widgets drop `from 00:00`.
    private static func scheduleLine(_ job: Job, short: Bool) -> String {
        let place = job.zone.cityName
        switch job.schedule {
        case .everyHours(let n) where short:
            return "Every \(n) hour\(n == 1 ? "" : "s") · \(place)"
        case .monthly(.day, let time):
            return "Monthly · \(time.text) \(place)"
        default:
            return ScheduleEngine.scheduleLine(job.schedule, in: job.zone)
        }
    }

    /// `28m`, `10h`, `16d`: minutes rounded up like the countdown, then whole hours or days.
    private static func compactCountdown(to run: Date, now: Date) -> String {
        let minutes = max(1, Int((run.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 24 * 60 { return "\(minutes / 60)h" }
        return "\(minutes / (24 * 60))d"
    }
}

import Foundation

/// One row of the Jobs list (board JobsList, decision BL).
public struct JobRowText: Equatable, Sendable {
    /// `Daily · 02:00 UTC · 4 children`: always in the job's zone.
    public let scheduleLine: String
    /// `Next 21:30 IST today`: in the shown zone (follows the UTC pill); `nil` when paused.
    public let next: String?
    /// `in 28 min`, `in 10h 28m`, `in 16 days`.
    public let countdown: String?
    /// Under 24 hours: the countdown is orange (spec §3.2).
    public let countdownIsSoon: Bool
    /// Last reviewed more than 90 days ago: neutral "Review" tag.
    public let needsReview: Bool
    /// `DST 1 Nov` (decision BJ).
    public let dstBadge: String?
}

public enum JobGroup: Sendable {
    case next24Hours, later, paused

    public var title: String {
        switch self {
        case .next24Hours: "Next 24 hours"
        case .later: "Later"
        case .paused: "Paused"
        }
    }
}

/// The Schedule card on Job detail (board JobDetail).
public struct JobScheduleCard: Equatable, Sendable {
    /// `Daily · 02:00 UTC`.
    public let title: String
    /// `07:30 IST on this phone`; `nil` for interval and cron schedules, or the phone's zone.
    public let phoneLine: String?
    /// `Fri 16 Oct · 07:30 IST`; `nil` when paused or it never runs.
    public let nextRun: String?
    public let countdown: String?
    public let countdownIsSoon: Bool
}

/// `+0:45  Gold views  08:15 IST` (board JobDetailScrolled).
public struct JobChildRow: Equatable, Sendable {
    public let offset: String
    public let name: String
    /// When the step is expected after the next run; `nil` when there is no next run.
    public let expected: String?
}

/// Wording for Jobs (spec §4.3, boards JobsList, JobDetail, JobEdit).
public enum JobText {
    /// Reviews older than this get the Review tag and banner (spec §4.3).
    static let reviewDays = 90

    public static func row(_ job: Job, now: Date, display: Zone, device: Zone) -> JobRowText {
        let run = job.nextRuns(after: now, count: 1).first
        let countdown = run.map { countdown(to: $0.instant, now: now) }
        let children = job.children.count
        let move = job.isPaused ? nil : ClockMove.first(zone: job.zone, device: device, pinned: .zoneTime, now: now,
                                                         within: ClockMove.badgeWindow)
        return JobRowText(
            scheduleLine: ScheduleEngine.scheduleLine(job.schedule, in: job.zone)
                + (children == 0 ? "" : " · \(children) \(children == 1 ? "child" : "children")"),
            next: run.map { nextLine($0.instant, now: now, display: display) },
            countdown: countdown?.text, countdownIsSoon: countdown?.isSoon ?? false,
            needsReview: reviewAge(job, today: ZoneClock.local(now, in: device).date) > reviewDays,
            dstBadge: move.map { "DST " + $0.date.dayMonthText })
    }

    /// Next 24 hours, Later (by next run; never-running jobs last), Paused (by title).
    /// Empty groups are left out.
    public static func groups(_ jobs: [Job], now: Date) -> [(group: JobGroup, jobs: [Job])] {
        let active = jobs.filter { !$0.isPaused }
            .map { ($0, $0.nextRuns(after: now, count: 1).first?.instant ?? .distantFuture) }
            .sorted { $0.1 < $1.1 }
        let soon = active.filter { $0.1.timeIntervalSince(now) < 24 * 3600 }.map(\.0)
        let later = active.filter { $0.1.timeIntervalSince(now) >= 24 * 3600 }.map(\.0)
        let paused = jobs.filter(\.isPaused).sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let all: [(group: JobGroup, jobs: [Job])] = [(.next24Hours, soon), (.later, later), (.paused, paused)]
        return all.filter { !$0.jobs.isEmpty }
    }

    /// `4 jobs · times in IST`.
    public static func header(count: Int, display: Zone, now: Date) -> String {
        "\(count) job\(count == 1 ? "" : "s") · times in \(ZoneClock.shortName(display, at: now))"
    }

    /// `in 28 min`, `in 10h 28m` (rounded up, like the meeting line) under 24 hours;
    /// `in 16 days` (whole days elapsed) after.
    public static func countdown(to run: Date, now: Date) -> (text: String, isSoon: Bool) {
        let seconds = run.timeIntervalSince(now)
        guard seconds < 24 * 3600 else {
            let days = Int(seconds / (24 * 3600))
            return ("in \(days) day\(days == 1 ? "" : "s")", false)
        }
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        let hours = minutes / 60, rest = minutes % 60
        let text = hours == 0 ? "in \(minutes) min" : rest == 0 ? "in \(hours)h" : "in \(hours)h \(rest)m"
        return (text, true)
    }

    /// `Last reviewed 12 Jul 2026 · 95 days ago` when older than 90 days.
    public static func reviewBanner(_ job: Job, today: CivilDate) -> String? {
        reviewAge(job, today: today) > reviewDays ? "Last reviewed " + reviewedText(job, today: today) : nil
    }

    /// `Reviewed 12 Jul 2026 · 95 days ago`, `Reviewed 15 Oct 2026 · today`.
    public static func reviewedLine(_ job: Job, today: CivilDate) -> String {
        "Reviewed " + reviewedText(job, today: today)
    }

    public static func scheduleCard(_ job: Job, now: Date, display: Zone, device: Zone) -> JobScheduleCard {
        let run = job.nextRuns(after: now, count: 1).first
        let countdown = run.map { countdown(to: $0.instant, now: now) }
        return JobScheduleCard(
            title: ScheduleEngine.scheduleLine(job.schedule, in: job.zone),
            phoneLine: phoneTimes(job, at: run?.instant ?? now, device: device).map { $0 + " on this phone" },
            nextRun: run.map { run in
                "\(ZoneClock.local(run.instant, in: display).date.shortText) · "
                    + ZoneClock.timeWithAbbreviation(run.instant, in: display)
            },
            countdown: countdown?.text, countdownIsSoon: countdown?.isSoon ?? false)
    }

    /// Each child's offset and when it's expected after the next run: elapsed time from
    /// the parent's start, not a wall time (decision BM).
    public static func childRows(_ job: Job, now: Date, display: Zone) -> [JobChildRow] {
        let run = job.nextRuns(after: now, count: 1).first
        return job.children.map { child in
            JobChildRow(offset: offsetText(child.offsetMinutes), name: child.name,
                        expected: run.map { ZoneClock.timeWithAbbreviation(
                            $0.instant + TimeInterval(child.offsetMinutes * 60), in: display) })
        }
    }

    /// `Children · 4 · expected at`.
    public static func childrenHeader(_ job: Job) -> String {
        "Children · \(job.children.count) · expected at"
    }

    /// Under the edit sheet's zone row: `07:30 IST on this phone · next run Fri 16 Oct`,
    /// or `Next run Thu 15 Oct · 21:30 IST` for interval and cron schedules.
    public static func editPreview(_ job: Job, now: Date, device: Zone) -> String? {
        guard let run = job.nextRuns(after: now, count: 1).first?.instant else { return nil }
        let date = ZoneClock.local(run, in: device).date.shortText
        if let times = phoneTimes(job, at: run, device: device) {
            return "\(times) on this phone · next run \(date)"
        }
        return "Next run \(date) · " + ZoneClock.timeWithAbbreviation(run, in: device)
    }

    /// `America/New_York · EDT now, EST from 1 Nov`, `Asia/Kolkata · IST all year`.
    public static func zoneLine(_ zone: Zone, now: Date) -> String {
        if zone.isUTC { return "UTC · no clock changes" }
        guard let change = ZoneClock.transitions(in: zone, from: now, to: now + AlarmText.noteWindow).first else {
            return "\(zone.id) · \(ZoneClock.shortName(zone, at: now)) all year"
        }
        return "\(zone.id) · \(change.before.shortName) now, \(change.after.shortName) from "
            + ZoneClock.local(change.instant, in: zone).date.dayMonthText
    }

    /// Under "Notifications are off" (board JobsNotifOff); `nil` when no reminder is affected.
    public static func notificationsOffDetail(_ jobs: [Job]) -> String? {
        let count = jobs.filter { $0.remindsMe && !$0.isPaused }.count
        return count == 0 ? nil : "Reminders for \(count) job\(count == 1 ? "" : "s") won't arrive."
    }

    /// `+0:45`, `+1:30`.
    public static func offsetText(_ minutes: Int) -> String {
        "+\(minutes / 60):" + twoDigits(minutes % 60)
    }

    // MARK: Private

    /// `Next 21:30 IST today`, `Next Fri 07:30 IST` within a week, else `Next Sun 1 Nov 10:30 IST`.
    private static func nextLine(_ run: Date, now: Date, display: Zone) -> String {
        let time = ZoneClock.timeWithAbbreviation(run, in: display)
        let date = ZoneClock.local(run, in: display).date
        switch date.days(since: ZoneClock.local(now, in: display).date) {
        case 0: return "Next \(time) today"
        case 1..<7: return "Next \(date.weekdayText) \(time)"
        default: return "Next \(date.shortText) \(time)"
        }
    }

    private static func reviewAge(_ job: Job, today: CivilDate) -> Int {
        today.days(since: job.lastReviewed)
    }

    /// `12 Jul 2026 · 95 days ago`.
    private static func reviewedText(_ job: Job, today: CivilDate) -> String {
        let days = reviewAge(job, today: today)
        let ago = switch days {
        case ...0: "today"
        case 1: "1 day ago"
        default: "\(days) days ago"
        }
        return "\(job.lastReviewed.dayMonthText) \(job.lastReviewed.year) · \(ago)"
    }

    /// The schedule's wall times on the phone at `instant`'s offsets: `07:30 IST`,
    /// `07:30, 19:30 IST`. `nil` for interval and cron schedules and the phone's own zone.
    private static func phoneTimes(_ job: Job, at instant: Date, device: Zone) -> String? {
        let times: [ClockTime]
        switch job.schedule {
        case .daily(let list): times = Array(Set(list)).sorted()
        case .weekly(_, let time), .monthly(_, let time): times = [time]
        case .everyMinutes, .everyHours, .cron: return nil
        }
        guard !job.zone.isSame(as: device), !times.isEmpty else { return nil }
        let shift = ZoneClock.state(device, at: instant).offsetSeconds - ZoneClock.state(job.zone, at: instant).offsetSeconds
        return times.map { $0.shifted(by: shift).text }.joined(separator: ", ") + " "
            + ZoneClock.shortName(device, at: instant)
    }
}

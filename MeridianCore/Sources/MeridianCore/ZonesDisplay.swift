import Foundation

/// The DayPager's three lines: `Thu 15 Oct`, `W42 · day 288`, `Today`.
public struct DayPagerText: Equatable, Sendable {
    public let title: String
    public let caption: String
    public let label: String
}

extension ZoneClock {
    /// `Today · −4h 30m`: the zone's local day and offset relative to `home` (decision K).
    public static func dayOffsetText(_ zone: Zone, relativeTo home: Zone, at instant: Date) -> String {
        let days = local(instant, in: zone).date.days(since: local(instant, in: home).date)
        let day = switch days {
        case 0: "Today"
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: days > 0 ? "+\(days) days" : "−\(-days) days"
        }
        let difference = zone.timeZone.secondsFromGMT(for: instant) - home.timeZone.secondsFromGMT(for: instant)
        return "\(day) · " + (difference == 0 ? "same time" : durationText(seconds: difference))
    }

    /// `DST in 8d`, `DST tomorrow`, `DST today`, from 14 days before a change; else `nil`.
    public static func dstBadgeText(_ zone: Zone, now: Date) -> String? {
        guard let change = zone.timeZone.nextDaylightSavingTimeTransition(after: now) else { return nil }
        let days = local(change, in: zone).date.days(since: local(now, in: zone).date)
        switch days {
        case 0: return "DST today"
        case 1: return "DST tomorrow"
        case 2...14: return "DST in \(days)d"
        default: return nil
        }
    }

    /// `+5h 30m`, `−4h 30m`, `+8h`, `−30m` (U+2212 minus).
    static func durationText(seconds: Int) -> String {
        let sign = seconds < 0 ? "−" : "+"
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        switch (hours, minutes) {
        case (0, _): return "\(sign)\(minutes)m"
        case (_, 0): return "\(sign)\(hours)h"
        default: return "\(sign)\(hours)h \(minutes)m"
        }
    }
}

extension OverlapEngine {
    /// DayPager text. Label priority (spec §4.1): "Clocks change in <zone>" > "Weekend" >
    /// relative day. Weekend follows the home zone's work days (Mon–Fri if it isn't a
    /// Planner zone, e.g. UTC mode).
    public static func pager(for date: CivilDate, today: CivilDate, home: Zone, zones: [PlannerZone]) -> DayPagerText {
        let iso = PeriodEngine.info(for: date)
        let caption = "W" + twoDigits(iso.isoWeek.week) + " · day \(iso.dayOfYear)"

        let axis = day(date, home: home, zones: []).axis
        let changing = zones.filter { !ZoneClock.transitions(in: $0.zone, from: axis.start, to: axis.end).isEmpty }
        let workDays = zones.first { $0.zone.id == home.id }?.workDays ?? [1, 2, 3, 4, 5]
        let offset = date.days(since: today)

        let label: String
        if !changing.isEmpty {
            label = "Clocks change in " + changing.map(\.name).joined(separator: ", ")
        } else if !workDays.contains(date.isoWeekday) {
            label = "Weekend"
        } else {
            label = switch offset {
            case 0: "Today"
            case 1: "Tomorrow"
            case -1: "Yesterday"
            default: offset > 0 ? "In \(offset) days" : "\(-offset) days ago"
            }
        }
        return DayPagerText(title: date.shortText, caption: caption, label: label)
    }
}

extension PlannerDay {
    /// `25-hour day` / `23-hour day` when the home day isn't 24 hours.
    public var lengthNote: String? {
        axis.duration == 86_400 ? nil : "\(hoursText)-hour day"
    }
}

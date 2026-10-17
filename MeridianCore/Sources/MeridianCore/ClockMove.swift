import Foundation

/// A clock change that moves something pinned to a zone's wall time (alarms, jobs) or to
/// UTC (Keep UTC time alarms), as seen from the phone. Drives DST badges and notes.
struct ClockMove {
    enum Pinned {
        /// Same wall time in its zone: moves on the phone when the two offsets drift apart.
        case zoneTime
        /// Same UTC time: moves in its zone or on the phone when either offset changes.
        case utcTime
    }

    /// DST badges on alarm and job rows look this far ahead (decision BJ; the boards show
    /// "DST 1 Nov" 16–17 days ahead, past the Clocks 14-day rule).
    static let badgeWindow: TimeInterval = 30 * 24 * 3600

    let instant: Date
    /// The date of the change in the zone that changed.
    let date: CivilDate
    let zoneAfter: Int
    let phoneAfter: Int
    let zoneMoves: Bool
    let phoneMoves: Bool

    /// The first clock change in `zone` or `device` within `within` that moves the item.
    static func first(zone: Zone, device: Zone, pinned: Pinned, now: Date, within: TimeInterval) -> ClockMove? {
        let end = now + within
        let changing = zone.isSame(as: device) ? [zone] : [zone, device]
        let candidates = changing
            .flatMap { changed in ZoneClock.transitions(in: changed, from: now, to: end).map { (changed, $0) } }
            .sorted { $0.1.instant < $1.1.instant }

        for (changed, transition) in candidates {
            let before = transition.instant.addingTimeInterval(-1)
            func offset(_ zone: Zone, _ instant: Date) -> Int { ZoneClock.state(zone, at: instant).offsetSeconds }
            let zoneBefore = offset(zone, before), zoneAfter = offset(zone, transition.instant)
            let phoneBefore = offset(device, before), phoneAfter = offset(device, transition.instant)
            let moves = switch pinned {
            case .zoneTime: phoneAfter - zoneAfter != phoneBefore - zoneBefore
            case .utcTime: zoneAfter != zoneBefore || phoneAfter != phoneBefore
            }
            if moves {
                return ClockMove(instant: transition.instant, date: ZoneClock.local(transition.instant, in: changed).date,
                                 zoneAfter: zoneAfter, phoneAfter: phoneAfter,
                                 zoneMoves: zoneAfter != zoneBefore, phoneMoves: phoneAfter != phoneBefore)
            }
        }
        return nil
    }
}

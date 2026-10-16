import Foundation

/// Planner scrubber maths (spec §4.1): 15-minute snap on the day's real axis, steps that
/// stay on the axis, and keeping the wall time when the day changes.
public enum Scrubber {
    static let slot: TimeInterval = TimeInterval(OverlapEngine.slotMinutes * 60)

    /// The snapped instant at `fraction` (0…1) across the axis, e.g. from a drag position.
    public static func instant(atFraction fraction: Double, in axis: DateInterval) -> Date {
        snap(axis.start.addingTimeInterval(fraction * axis.duration), in: axis)
    }

    /// Where `instant` sits across the axis (0…1), e.g. to place the selection line.
    public static func fraction(of instant: Date, in axis: DateInterval) -> Double {
        instant.timeIntervalSince(axis.start) / axis.duration
    }

    /// Nearest 15-minute slot start (halves round up), clamped to the axis's slots.
    public static func snap(_ instant: Date, in axis: DateInterval) -> Date {
        let lastSlot = (axis.duration / slot).rounded(.up) - 1
        let slots = (instant.timeIntervalSince(axis.start) / slot).rounded(.toNearestOrAwayFromZero)
        return axis.start.addingTimeInterval(min(max(slots, 0), lastSlot) * slot)
    }

    /// ±15 (buttons) or ±30 (VoiceOver) minutes, staying on the axis.
    public static func step(_ instant: Date, byMinutes minutes: Int, in axis: DateInterval) -> Date {
        snap(instant.addingTimeInterval(TimeInterval(minutes * 60)), in: axis)
    }

    /// The scrubber keeps its wall time when the day changes; a skipped time moves to the
    /// next valid slot, a repeated one uses the first occurrence (gap/overlap rule).
    public static func instant(keeping time: ClockTime, on date: CivilDate, in zone: Zone) -> Date {
        ZoneClock.resolve(LocalDateTime(date: date, hour: time.hour, minute: time.minute), in: zone, occurrence: .first).instant
    }

    public static func wallTime(of instant: Date, in zone: Zone) -> ClockTime {
        let local = ZoneClock.local(instant, in: zone)
        return ClockTime(local.hour, local.minute)
    }
}

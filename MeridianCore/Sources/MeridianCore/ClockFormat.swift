import Foundation

/// Clock strings for the UI. Views call this instead of touching `TimeZone` or `Calendar`.
public enum ClockFormat {
    /// Gregorian calendar pinned to UTC, so the device's zone and calendar never leak in.
    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// `"15:32:07"`: the UTC wall time of `date`, 24-hour, zero-padded.
    /// Fractional seconds are dropped (a clock shows the second that has started).
    public static func utcTime(_ date: Date) -> String {
        let parts = utcCalendar.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }
}

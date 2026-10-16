import Foundation
import Testing
@testable import MeridianCore

/// Expected values computed independently with Python:
/// `datetime.fromtimestamp(t, timezone.utc)`.
@Suite("ClockFormat.utcTime")
struct ClockFormatTests {
    @Test("Formats as zero-padded HH:mm:ss in UTC", arguments: [
        (0.0, "00:00:00"),                  // Unix epoch
        (-1.0, "23:59:59"),                 // negative epoch, previous day
        (86_399.0, "23:59:59"),             // last second of day 1
        (1_760_542_327.0, "15:32:07"),      // spec §4.1 pill example, 15 Oct 2025
        (1_792_000_000.0, "17:46:40"),      // 14 Oct 2026
    ])
    func formats(seconds: Double, expected: String) {
        #expect(ClockFormat.utcTime(Date(timeIntervalSince1970: seconds)) == expected)
    }

    @Test("Truncates fractional seconds instead of rounding up")
    func truncates() {
        #expect(ClockFormat.utcTime(Date(timeIntervalSince1970: 0.999)) == "00:00:00")
        #expect(ClockFormat.utcTime(Date(timeIntervalSince1970: -0.5)) == "23:59:59")
    }
}

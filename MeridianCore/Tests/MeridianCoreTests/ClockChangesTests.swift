import Foundation
import Testing
@testable import MeridianCore

/// Upcoming clock changes sheet (board ClockChanges: the next change per zone) and the
/// Clocks "warn before clocks change" banner (board ClocksBanner). Day counts are calendar
/// days in the changing zone, like the DST badge (decision M). Checked with Python zoneinfo.
@Suite("Clock changes")
struct ClockChangesTests {
    static let ist = Zone("Asia/Kolkata")!
    static let london = Zone("Europe/London")!
    static let sf = Zone("America/Los_Angeles")!
    static let lordHowe = Zone("Australia/Lord_Howe")!

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static let zones: [(zone: Zone, name: String)] = [(ist, "Mumbai"), (london, "London"), (sf, "San Francisco")]

    // MARK: Sheet cards

    @Test("One card per zone, soonest change first, zones without changes last")
    func cards() {
        let cards = ZoneClock.changeCards(for: Self.zones, now: Self.utc("2026-10-16T10:15:07Z"), device: Self.ist)
        #expect(cards == [
            ClockChangeCard(name: "London", instant: Self.utc("2026-10-25T01:00:00Z"), headline: "Back 1 hour",
                            offset: "UTC+0", detail: "Sun 25 Oct 2026 · 02:00 BST → 01:00 GMT",
                            phone: "06:30 IST on this phone · in 9 days"),
            ClockChangeCard(name: "San Francisco", instant: Self.utc("2026-11-01T09:00:00Z"), headline: "Back 1 hour",
                            offset: "UTC−8", detail: "Sun 1 Nov 2026 · 02:00 PDT → 01:00 PST",
                            phone: "14:30 IST on this phone · in 16 days"),
            ClockChangeCard(name: "Mumbai", instant: nil, headline: "No clock changes", offset: "UTC+5:30",
                            detail: "IST all year", phone: nil),
        ])
    }

    @Test("Spring forward, tomorrow, and a half-hour change")
    func cardVariants() throws {
        let spring = try #require(ZoneClock.changeCards(for: [(Self.london, "London")], now: Self.utc("2027-03-20T12:00:00Z"),
                                           device: Self.ist).first)
        #expect(spring.headline == "Forward 1 hour")
        #expect(spring.offset == "UTC+1")
        #expect(spring.detail == "Sun 28 Mar 2027 · 01:00 GMT → 02:00 BST")
        #expect(spring.phone == "06:30 IST on this phone · in 8 days")

        let tomorrow = try #require(ZoneClock.changeCards(for: [(Self.london, "London")], now: Self.utc("2026-10-24T12:00:00Z"),
                                             device: Self.ist).first)
        #expect(tomorrow.phone == "06:30 IST on this phone · tomorrow")

        // Lord Howe Island moves its clocks by 30 minutes.
        let half = try #require(ZoneClock.changeCards(for: [(Self.lordHowe, "Lord Howe")], now: Self.utc("2026-10-01T00:00:00Z"),
                                         device: Self.ist).first)
        #expect(half.headline == "Forward 30 min")
    }

    @Test("UTC and duplicate zones")
    func cardsUTCAndDuplicates() {
        let cards = ZoneClock.changeCards(for: [(.utc, "UTC"), (Self.london, "London"), (Self.london, "Office")],
                                          now: Self.utc("2026-10-16T10:15:07Z"), device: Self.ist)
        #expect(cards.map(\.name) == ["London", "UTC"])                  // first name wins
        #expect(cards.last == ClockChangeCard(name: "UTC", instant: nil, headline: "No clock changes", offset: "UTC",
                                            detail: "UTC all year", phone: nil))
    }

    // MARK: Clocks warning banner

    @Test("Warning names the soonest change within 14 days, against home")
    func warning() {
        let now = Self.utc("2026-10-16T10:15:07Z")
        #expect(ZoneClock.changeWarning(for: Self.zones, home: Self.ist, now: now) == ClockChangeWarning(
            title: "London clocks go back 1 hour on Sun 25 Oct",
            detail: "In 9 days. London becomes GMT (UTC+0), 5h 30m behind you instead of 4h 30m."))
        #expect(ZoneClock.changeWarning(for: Self.zones, home: Self.ist, now: Self.utc("2026-10-26T10:00:00Z"))
                == ClockChangeWarning(
                    title: "San Francisco clocks go back 1 hour on Sun 1 Nov",
                    detail: "In 6 days. San Francisco becomes PST (UTC−8), 13h 30m behind you instead of 12h 30m."))
    }

    @Test("The home zone's own change has no comparison; nothing within 14 days means no banner")
    func warningHomeAndNone() {
        #expect(ZoneClock.changeWarning(for: Self.zones, home: Self.london, now: Self.utc("2026-10-24T12:00:00Z"))
                == ClockChangeWarning(title: "London clocks go back 1 hour on Sun 25 Oct",
                                      detail: "Tomorrow. London becomes GMT (UTC+0)."))
        #expect(ZoneClock.changeWarning(for: Self.zones, home: Self.ist, now: Self.utc("2026-10-01T00:00:00Z")) == nil)
        #expect(ZoneClock.changeWarning(for: [(Self.ist, "Mumbai")], home: Self.ist,
                                        now: Self.utc("2026-10-16T10:15:07Z")) == nil)
    }
}

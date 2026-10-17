import Foundation
import Testing
@testable import MeridianCore

/// Board Settings and decision BY. Locale first days are CLDR's (US Sunday, UK Monday);
/// `@fw=sat` is the Unicode locale keyword that sets the first weekday.
@Suite("Settings values")
struct SettingsValuesTests {
    @Test("Week start titles")
    func titles() {
        #expect(WeekStart.allCases.map(\.title) == ["Follow locale", "Monday", "Sunday", "Saturday"])
    }

    @Test("Week start resolves to an ISO weekday", arguments: [
        (WeekStart.monday, "en_US", 1),
        (WeekStart.sunday, "en_GB", 7),
        (WeekStart.saturday, "en_GB", 6),
        (WeekStart.followLocale, "en_US", 7),
        (WeekStart.followLocale, "en_GB", 1),
        (WeekStart.followLocale, "en_GB@fw=sat", 6),
    ])
    func firstDay(start: WeekStart, locale: String, expected: Int) {
        #expect(start.firstDay(for: Locale(identifier: locale)) == expected)
    }

    @Test("Days in display order")
    func ordered() {
        #expect(Weekdays.ordered(from: 1) == [1, 2, 3, 4, 5, 6, 7])
        #expect(Weekdays.ordered(from: 7) == [7, 1, 2, 3, 4, 5, 6])
        #expect(Weekdays.ordered(from: 6) == [6, 7, 1, 2, 3, 4, 5])
    }

    @Test("Work days summary", arguments: [
        ([1, 2, 3, 4, 5], 1, "Mon–Fri"),                 // board Settings
        ([1, 2, 3, 4, 6], 1, "Mon–Thu, Sat"),
        ([7, 1, 2, 3, 4], 7, "Sun–Thu"),                 // Sunday-first week
        ([7, 1, 2, 3, 4], 1, "Mon–Thu, Sun"),
        ([6, 7], 1, "Sat, Sun"),
        ([1, 3], 1, "Mon, Wed"),
        ([1, 2, 3, 4, 5, 6, 7], 1, "Every day"),
        ([], 1, "None"),
    ])
    func summary(days: [Int], first: Int, expected: String) {
        #expect(Weekdays.summary(Set(days), from: first) == expected)
    }

    @Test("Working hours range")
    func range() {
        #expect(ClockTime.rangeText(ClockTime(9, 0), ClockTime(18, 0)) == "09:00–18:00")
        #expect(ClockTime.rangeText(ClockTime(7, 30), ClockTime(16, 5)) == "07:30–16:05")
    }

    @Test("Time zone data version looks like 2025b")
    func dataVersion() {
        #expect(ZoneClock.dataVersion.wholeMatch(of: /\d{4}[a-z]/) != nil)
    }
}

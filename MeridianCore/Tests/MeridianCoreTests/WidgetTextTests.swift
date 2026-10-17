import Foundation
import Testing
@testable import MeridianCore

/// Boards WidgetFull, JobsWidgetFull, JobsWidgetLarge and JobsLockWidgets: phone in IST,
/// Thu 15 Oct 2026 15:32:07Z = 21:02 IST. Checked with Python zoneinfo: London 16:32 BST,
/// SF 08:32 PDT; the IST day starts 14 Oct 18:30Z, so now is 0.87647 of it, London's work
/// bar is 0.5625–0.9375 and SF's 0–0.2708 and 0.8958–1. Jobs: 16:00Z = 21:30 IST (27m53s
/// away), Fri 02:00Z = 07:30 IST (10h 27m 53s), 1 Nov 01:00 EDT = 05:00Z = 10:30 IST
/// (16 days 13h); children at 07:30, 07:50, 08:15, 09:00 IST.
@Suite("Widget text")
struct WidgetTextTests {
    static let ist = Zone("Asia/Kolkata")!
    static let now = JobTextTests.now

    static let zones = WidgetSnapshot(zones: [
        .init(ianaID: "Asia/Kolkata", name: "Mumbai", isHome: true),
        .init(ianaID: "Europe/London", name: "London", isHome: false),
        .init(ianaID: "America/Los_Angeles", name: "San Francisco", isHome: false),
    ])
    static let jobs = WidgetSnapshot(jobs: JobTextTests.board)

    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0005 }

    // MARK: Clock

    @Test("Clock widget: UTC, then home with its label")
    func clock() {
        let text = WidgetText.clock(Self.zones, now: Self.now)
        #expect(text.utcTime == "15:32")
        #expect(text.utcDate == "Thu 15 Oct")
        #expect(text.home == .init(name: "Mumbai", time: "21:02", label: "IST (UTC+5:30)", dstBadge: nil))
    }

    @Test("Clock widget: DST badge for a home that changes within 14 days; none for a UTC home")
    func clockBadge() {
        let london = WidgetSnapshot(zones: [.init(ianaID: "Europe/London", name: "London", isHome: true)])
        #expect(WidgetText.clock(london, now: Self.now).home?.dstBadge == "DST in 10d")   // 25 Oct
        let utc = WidgetSnapshot(zones: [.init(ianaID: "UTC", name: "UTC", isHome: true)])
        #expect(WidgetText.clock(utc, now: Self.now).home == nil)
        #expect(WidgetText.clock(.empty, now: Self.now).home == nil)
    }

    @Test("UTC accessory")
    func utcInline() {
        #expect(WidgetText.utcInline(now: Self.now) == "UTC 15:32")
    }

    // MARK: Planner

    @Test("Planner widget rows (board WidgetFull)")
    func plannerRows() throws {
        let text = try #require(WidgetText.planner(Self.zones, now: Self.now))
        #expect(text.rows.map(\.name) == ["Mumbai", "London", "San Francisco"])
        #expect(text.rows.map(\.time) == ["21:02", "16:32", "08:32"])
        #expect(text.rows.map(\.isHome) == [true, false, false])
        #expect(text.rows.map(\.changesClocks) == [false, false, false])
        #expect(Self.close(text.now, 0.87647))

        let londonWork = try #require(text.rows[1].bars.first { $0.kind == .work })
        #expect(Self.close(londonWork.start, 0.5625) && Self.close(londonWork.end, 0.9375))
        let sf = text.rows[2].bars
        #expect(sf.first?.kind == .work && Self.close(sf.first!.start, 0) && Self.close(sf.first!.end, 0.27083))
        #expect(sf.last?.kind == .work && Self.close(sf.last!.start, 0.89583) && Self.close(sf.last!.end, 1))
    }

    @Test("Planner widget best window (board WidgetFull)")
    func plannerBest() throws {
        let text = try #require(WidgetText.planner(Self.zones, now: Self.now))
        #expect(text.bestTitle == "Best compromise")
        #expect(text.bestTime == "16:00–16:30 UTC")
        #expect(text.counts == "3 of 3 awake · Mumbai in stretch")
    }

    @Test("Planner widget: later day shows the UTC weekday; one zone gives nil")
    func plannerLater() throws {
        // 18:05Z = 23:35 IST: no 30-minute window is left in Thursday's IST day.
        let late = JobTextTests.utc("2026-10-15T18:05:00Z")
        let text = try #require(WidgetText.planner(Self.zones, now: late))
        #expect(text.bestTime?.hasPrefix("Fri ") == true)
        let one = WidgetSnapshot(zones: [Self.zones.zones[0]])
        #expect(WidgetText.planner(one, now: Self.now) == nil)
    }

    @Test("Planner widget: a zone changing clocks that day is tagged")
    func plannerDST() throws {
        // Sun 25 Oct 2026, London's 25-hour day; it's 10:00 IST then.
        let text = try #require(WidgetText.planner(Self.zones, now: JobTextTests.utc("2026-10-25T04:30:00Z")))
        #expect(text.rows.map(\.changesClocks) == [false, true, false])
    }

    // MARK: Jobs

    @Test("Jobs widget rows (boards JobsWidgetFull and JobsWidgetLarge)")
    func jobs() {
        let text = WidgetText.jobs(Self.jobs, now: Self.now, device: Self.ist)
        #expect(text.zoneName == "IST")
        #expect(text.rows.map(\.title) == ["Marketing dashboard refresh", "Netsuite pipeline run",
                                           "Month-end close extract"])
        #expect(text.rows.map(\.day) == [nil, "Fri", "1 Nov"])
        #expect(text.rows.map(\.time) == ["21:30", "07:30", "10:30"])
        #expect(text.rows.map(\.shortLine) == ["Every 4 hours · UTC", "Daily · 02:00 UTC · 4 children",
                                               "Monthly · 01:00 New York · DST"])
        #expect(text.rows.map(\.line) == ["Every 4 hours · from 00:00 UTC", "Daily · 02:00 UTC",
                                          "Monthly · 01:00 New York · DST"])
        #expect(text.rows.map(\.countdown) == ["in 28 min", "in 10h 28m", "in 16 days"])
        #expect(text.rows.map(\.isSoon) == [true, true, false])
        #expect(text.rows.map(\.compactCountdown) == ["28m", "10h", "16d"])
        #expect(text.rows[1].children == [
            .init(time: "07:30", offset: "+0:00", name: "Bronze load"),
            .init(time: "07:50", offset: "+0:20", name: "Silver transform"),
            .init(time: "08:15", offset: "+0:45", name: "Gold views"),
            .init(time: "09:00", offset: "+1:30", name: "Sales dashboard refresh"),
        ])
        #expect(WidgetText.nextJobInline(text) == "Next job 21:30")
    }

    @Test("Jobs widget in UTC mode")
    func jobsUTC() {
        var snapshot = Self.jobs
        snapshot.isUTCMode = true
        let text = WidgetText.jobs(snapshot, now: Self.now, device: Self.ist)
        #expect(text.zoneName == "UTC")
        #expect(text.rows.map(\.day) == [nil, "Fri", "1 Nov"])
        #expect(text.rows.map(\.time) == ["16:00", "02:00", "05:00"])
        #expect(text.rows[1].children.map(\.time) == ["02:00", "02:20", "02:45", "03:30"])
    }

    @Test("Jobs widget: limit, a later first job, and no jobs")
    func jobsEdges() {
        #expect(WidgetText.jobs(Self.jobs, now: Self.now, device: Self.ist, limit: 2).rows.count == 2)
        let later = WidgetSnapshot(jobs: [JobTextTests.netsuite])
        #expect(WidgetText.nextJobInline(WidgetText.jobs(later, now: Self.now, device: Self.ist)) == "Next job Fri 07:30")
        let none = WidgetText.jobs(.empty, now: Self.now, device: Self.ist)
        #expect(none.rows.isEmpty)
        #expect(WidgetText.nextJobInline(none) == "No upcoming jobs")
    }

    // MARK: Timeline

    @Test("Timeline: now, then each whole UTC minute for 2 hours (decision BS)")
    func timeline() {
        let dates = WidgetText.timelineDates(from: Self.now)            // 15:32:07Z
        #expect(dates.count == 121)
        #expect(dates[0] == Self.now)
        #expect(dates[1] == Date(timeIntervalSince1970: 1_792_078_380))  // 15:33:00Z
        #expect(dates.last == Date(timeIntervalSince1970: 1_792_085_520)) // 17:32:00Z
        let onMinute = Date(timeIntervalSince1970: 1_792_078_380)
        #expect(WidgetText.timelineDates(from: onMinute)[1] == onMinute + 60)
        #expect(WidgetText.timelineDates(from: Date(timeIntervalSince1970: -30))[1] == Date(timeIntervalSince1970: 0))
    }
}

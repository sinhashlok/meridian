import Foundation
import Testing
@testable import MeridianCore

/// docs/design/fixtures.md § OverlapEngine, with decisions D (ranking: fewest asleep,
/// then fewest in stretch, then soonest), E (weekend skip) and G (defaults, wording).
@Suite("OverlapEngine")
struct OverlapEngineTests {
    static let mumbai = PlannerZone(zone: Zone("Asia/Kolkata")!, name: "Mumbai")
    static let london = PlannerZone(zone: Zone("Europe/London")!, name: "London")
    static let sf = PlannerZone(zone: Zone("America/Los_Angeles")!, name: "SF")
    static let all = [mumbai, london, sf]

    static func utc(_ iso: String) -> Date { try! EpochParser.parseISO8601(iso).date }

    static func interval(_ start: String, _ end: String) -> DateInterval {
        DateInterval(start: utc(start), end: utc(end))
    }

    /// Row `index` of `day`, failing the test (not crashing) if it's missing.
    static func row(_ day: PlannerDay, _ index: Int) throws -> PlannerRow {
        try #require(day.rows.indices.contains(index) ? day.rows[index] : nil)
    }

    // MARK: Fixture rows

    @Test("Thu 15 Oct: no all-work overlap; best compromise 16:00–16:30Z, Mumbai in stretch")
    func thursday() throws {
        let result = try #require(OverlapEngine.bestWindow(from: CivilDate(2026, 10, 15), home: Self.mumbai.zone,
                                                           zones: Self.all))
        #expect(result.day == CivilDate(2026, 10, 15))
        #expect(result.window.interval == Self.interval("2026-10-15T16:00:00Z", "2026-10-15T16:30:00Z"))
        #expect(result.window.isAllWork == false)
        #expect(result.allWorkRanges.isEmpty)
        #expect(result.countsText == "3 of 3 awake · Mumbai in stretch")
        #expect(result.skipNote == nil)
    }

    @Test("Sun 25 Oct, home London: weekend in all 3, skip to Mon 26 Oct 16:00–16:30Z")
    func sundaySkip() throws {
        let result = try #require(OverlapEngine.bestWindow(from: CivilDate(2026, 10, 25), home: Self.london.zone,
                                                           zones: Self.all))
        #expect(result.day == CivilDate(2026, 10, 26))
        #expect(result.window.interval == Self.interval("2026-10-26T16:00:00Z", "2026-10-26T16:30:00Z"))
        #expect(result.skipNote == "Skipping the weekend · Mon 26 Oct")
        #expect(result.countsText == "3 of 3 awake · Mumbai in stretch")
    }

    @Test("London axis on Sun 25 Oct is 25 h, with the clock change marked")
    func londonAxis() {
        let day = OverlapEngine.day(CivilDate(2026, 10, 25), home: Self.london.zone, zones: Self.all)
        #expect(day.axis == Self.interval("2026-10-24T23:00:00Z", "2026-10-26T00:00:00Z"))   // 00:00 BST to 00:00 GMT
        #expect(day.axis.duration == 25 * 3600)
        #expect(day.transitions.map(\.zoneName) == ["London"])
        #expect(day.transitions.first?.transition.instant == Self.utc("2026-10-25T01:00:00Z"))
    }

    @Test("Week of 26–31 Oct: London–SF gap is 7 h (normally 8 h)")
    func londonSFGap() throws {
        func gap(on date: CivilDate) throws -> TimeInterval {
            let day = OverlapEngine.day(date, home: Self.mumbai.zone, zones: Self.all)
            let londonWork = try #require(try Self.row(day, 1).segments.first { $0.kind == .work })
            let sfWork = try #require(try Self.row(day, 2).segments.first { $0.kind == .work && $0.interval.start > londonWork.interval.start })
            return sfWork.interval.start.timeIntervalSince(londonWork.interval.start)
        }
        for day in 26...30 {
            #expect(try gap(on: CivilDate(2026, 10, day)) == 7 * 3600, "26–30 Oct: \(day)")
        }
        #expect(try gap(on: CivilDate(2026, 10, 15)) == 8 * 3600)
    }

    @Test("Mumbai work 09:00–18:00 IST = 03:30–12:30Z; SF work 09:00–18:00 PDT = 16:00–01:00Z")
    func workInUTC() throws {
        let mumbaiDay = OverlapEngine.day(CivilDate(2026, 10, 15), home: Self.mumbai.zone, zones: [Self.mumbai])
        #expect(try Self.row(mumbaiDay, 0).segments.filter { $0.kind == .work }.map(\.interval)
                == [Self.interval("2026-10-15T03:30:00Z", "2026-10-15T12:30:00Z")])
        let sfDay = OverlapEngine.day(CivilDate(2026, 10, 15), home: Self.sf.zone, zones: [Self.sf])
        #expect(try Self.row(sfDay, 0).segments.filter { $0.kind == .work }.map(\.interval)
                == [Self.interval("2026-10-15T16:00:00Z", "2026-10-16T01:00:00Z")])
    }

    // MARK: Counts wording

    @Test("Counts wording", arguments: [
        ("2026-10-15T16:00:00Z", "3 of 3 awake · Mumbai in stretch"),
        ("2026-10-15T14:00:00Z", "3 of 3 awake · Mumbai, SF in stretch"),
        ("2026-10-15T08:00:00Z", "2 of 3 awake · SF asleep"),                    // decision G
        ("2026-10-15T20:00:00Z", "2 of 3 awake · London in stretch · Mumbai asleep"),   // SF 13:00 work
        ("2026-10-15T05:00:00Z", "1 of 3 awake · London, SF asleep"),
    ])
    func counts(start: String, text: String) {
        let window = OverlapEngine.window(starting: Self.utc(start), minutes: 30, zones: Self.all)
        #expect(window.countsText == text)
    }

    @Test("All in work hours: London and SF on 15 Oct")
    func allWork() throws {
        let result = try #require(OverlapEngine.bestWindow(from: CivilDate(2026, 10, 15), home: Self.london.zone,
                                                           zones: [Self.london, Self.sf]))
        #expect(result.window.interval == Self.interval("2026-10-15T16:00:00Z", "2026-10-15T16:30:00Z"))
        #expect(result.window.isAllWork)
        #expect(result.countsText == "2 of 2 in work hours")
        #expect(result.allWorkRanges == [Self.interval("2026-10-15T16:00:00Z", "2026-10-15T17:00:00Z")])
    }

    // MARK: Weekend (decision E) and defaults (decision G)

    @Test("An SF-home Friday is not skipped: its 09:00 PDT slot is still Friday in Mumbai")
    func sfFriday() throws {
        let result = try #require(OverlapEngine.bestWindow(from: CivilDate(2026, 10, 16), home: Self.sf.zone,
                                                           zones: Self.all))
        #expect(result.day == CivilDate(2026, 10, 16))
        #expect(result.skipNote == nil)
        #expect(result.window.interval == Self.interval("2026-10-16T16:00:00Z", "2026-10-16T16:30:00Z"))
    }

    @Test("Weekend days have no work bars, only stretch and sleep")
    func weekendRows() throws {
        let saturday = OverlapEngine.day(CivilDate(2026, 10, 17), home: Self.london.zone, zones: [Self.london])
        let kinds = Set(try Self.row(saturday, 0).segments.map(\.kind))
        #expect(kinds == [.stretch, .sleep])
        #expect(try Self.row(saturday, 0).segments.first { $0.kind == .stretch }?.interval
                == Self.interval("2026-10-17T06:00:00Z", "2026-10-17T21:00:00Z"))   // 07:00–22:00 BST
    }

    @Test("Default stretch is 2 h before work and 4 h after: 07–09 and 18–22")
    func defaultStretch() throws {
        let day = OverlapEngine.day(CivilDate(2026, 10, 15), home: Self.mumbai.zone, zones: [Self.mumbai])
        #expect(try Self.row(day, 0).segments.map(\.kind) == [.sleep, .stretch, .work, .stretch, .sleep])
        #expect(try Self.row(day, 0).segments.filter { $0.kind == .stretch }.map(\.interval) == [
            Self.interval("2026-10-15T01:30:00Z", "2026-10-15T03:30:00Z"),
            Self.interval("2026-10-15T12:30:00Z", "2026-10-15T16:30:00Z"),
        ])
    }

    @Test("Segments tile the axis with no gaps")
    func segmentsTile() {
        let day = OverlapEngine.day(CivilDate(2026, 10, 25), home: Self.london.zone, zones: Self.all)
        #expect(day.rows.count == 3)
        for row in day.rows {
            #expect(row.segments.first?.interval.start == day.axis.start)
            #expect(row.segments.last?.interval.end == day.axis.end)
            #expect(zip(row.segments, row.segments.dropFirst()).allSatisfy { $0.interval.end == $1.interval.start })
        }
    }
}

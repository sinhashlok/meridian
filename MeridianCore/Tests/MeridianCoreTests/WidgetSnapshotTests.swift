import Foundation
import Testing
@testable import MeridianCore

/// Decision BR: the JSON the app writes to the App Group for the widgets.
@Suite("Widget snapshot")
struct WidgetSnapshotTests {
    static let board = WidgetSnapshot(
        zones: [.init(ianaID: "Asia/Kolkata", name: "Mumbai", isHome: true),
                .init(ianaID: "Europe/London", name: "London", isHome: false),
                .init(ianaID: "America/Los_Angeles", name: "SF", isHome: false, workDays: [1, 2, 3, 4])],
        jobs: [Job(title: "Marketing dashboard refresh", category: .dashboard, schedule: .everyHours(4), lastReviewed: CivilDate(2026, 10, 1))],
        isUTCMode: true)

    @Test("Round-trips through JSON")
    func roundTrip() {
        #expect(WidgetSnapshot.decoded(from: Self.board.encoded()) == Self.board)
    }

    @Test("Missing, empty or unreadable data reads as empty", arguments: [
        nil, Data(), Data("not json".utf8), Data("{}".utf8),
    ])
    func unreadable(data: Data?) {
        #expect(WidgetSnapshot.decoded(from: data) == .empty)
    }

    @Test("Keys the widget doesn't know yet are ignored; missing keys take defaults")
    func tolerant() {
        let json = #"{"zones":[{"ianaID":"UTC","name":"UTC","isHome":true,"workStart":{"hour":9,"minute":0},"workEnd":{"hour":18,"minute":0},"workDays":[1]}],"future":1}"#
        let snapshot = WidgetSnapshot.decoded(from: Data(json.utf8))
        #expect(snapshot.zones.map(\.name) == ["UTC"])
        #expect(snapshot.jobs.isEmpty)
        #expect(snapshot.isUTCMode == false)
    }

    @Test("Home is the marked zone, else the first")
    func home() {
        #expect(Self.board.home?.name == "Mumbai")
        var noHome = Self.board
        noHome.zones = noHome.zones.map { var zone = $0; zone.isHome = false; return zone }
        #expect(noHome.home?.name == "Mumbai")
        #expect(WidgetSnapshot.empty.home == nil)
    }

    @Test("Planner zones: home first, invalid ids and inverted hours dropped")
    func plannerZones() {
        var snapshot = Self.board
        snapshot.zones.insert(.init(ianaID: "Mars/Olympus", name: "Mars", isHome: false), at: 0)
        snapshot.zones.append(.init(ianaID: "Asia/Tokyo", name: "Tokyo", isHome: false,
                                    workStart: ClockTime(18, 0), workEnd: ClockTime(9, 0)))
        snapshot.zones.swapAt(1, 2)   // London before Mumbai
        #expect(snapshot.plannerZones.map(\.name) == ["Mumbai", "London", "SF"])
        #expect(snapshot.plannerZones.last?.workDays == [1, 2, 3, 4])
    }
}

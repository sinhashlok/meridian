import Foundation
import Testing
@testable import MeridianCore

/// Zone search (spec §4.1: by city, country, abbreviation, offset; decision H).
@Suite("ZoneCatalog")
struct ZoneCatalogTests {
    static let october = try! EpochParser.parseISO8601("2026-10-15T16:00:00Z").date

    static func names(_ query: String) -> [String] {
        ZoneCatalog.search(query, at: october).map(\.name)
    }

    @Test("Every catalog entry is a real IANA zone, with no duplicate cities")
    func catalogValid() {
        let invalid = ZoneCatalog.entries.filter { Zone($0.zoneID) == nil }.map(\.zoneID)
        #expect(invalid.isEmpty, "\(invalid)")
        let cities = ZoneCatalog.entries.map(\.city)
        #expect(Set(cities).count == cities.count)
        #expect(ZoneCatalog.entries.count >= 140)
    }

    @Test("First-launch suggestions: London · New York · San Francisco · Singapore · UTC")
    func suggestions() {
        #expect(ZoneCatalog.suggestions.map(\.city) == ["London", "New York", "San Francisco", "Singapore", "UTC"])
    }

    @Test("City prefix ranks first")
    func cityPrefix() {
        #expect(Self.names("lon").first == "London")
        #expect(Self.names("new york").first == "New York")
        #expect(Self.names("san f").first == "San Francisco")
    }

    @Test("Country finds its cities")
    func country() {
        let india = Self.names("india")
        #expect(["Mumbai", "Delhi", "Bengaluru", "Kolkata"].allSatisfy(india.contains))
    }

    @Test("Abbreviation and offset", arguments: [
        ("ist", "Mumbai"), ("BST", "London"), ("pdt", "San Francisco"),
        ("+5:30", "Mumbai"), ("UTC+5:30", "Colombo"), ("-7", "Phoenix"), ("UTC−7", "Vancouver"),
    ])
    func abbreviationAndOffset(query: String, expected: String) {
        #expect(Self.names(query).contains(expected))
    }

    @Test("Offset search matches the offset on the given date, not all year")
    func offsetIsDated() {
        #expect(Self.names("-7").contains("Denver") == false)        // MDT is −6 in October
    }

    @Test("Accents and underscores don't matter")
    func folding() {
        #expect(Self.names("sao paulo").first == "São Paulo")
        #expect(Self.names("bogota").first == "Bogotá")
    }

    @Test("Zones not in the catalog are still reachable by id or city")
    func fallback() {
        let result = ZoneCatalog.search("Tarawa", at: Self.october).first
        #expect(result?.zone.id == "Pacific/Tarawa")
        #expect(ZoneCatalog.search("America/Indiana/Knox", at: Self.october).first?.zone.id == "America/Indiana/Knox")
    }

    @Test("Results carry a detail line with country and label")
    func detail() {
        let london = ZoneCatalog.search("London", at: Self.october).first
        #expect(london?.detail == "United Kingdom · BST (UTC+1)")
        #expect(ZoneCatalog.search("UTC", at: Self.october).first?.detail == "Coordinated Universal Time · UTC")
    }

    @Test("Empty query returns nothing (the UI shows suggestions)")
    func empty() {
        #expect(ZoneCatalog.search("  ", at: Self.october).isEmpty)
    }
}

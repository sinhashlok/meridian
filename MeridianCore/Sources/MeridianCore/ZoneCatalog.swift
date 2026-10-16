import Foundation

/// A city people search for, with its country and IANA zone.
public struct ZoneCatalogEntry: Hashable, Sendable {
    public let city: String
    public let country: String
    public let zoneID: String

    init(_ city: String, _ country: String, _ zoneID: String) {
        self.city = city
        self.country = country
        self.zoneID = zoneID
    }

    public var zone: Zone {
        guard let zone = Zone(zoneID) else { preconditionFailure("catalog has an invalid zone \(zoneID)") }
        return zone
    }
}

/// One row in Add zone search.
public struct ZoneSearchResult: Hashable, Sendable {
    /// City name, or the city part of the IANA id for zones outside the catalog.
    public let name: String
    /// `United Kingdom · BST (UTC+1)`.
    public let detail: String
    public let zone: Zone
}

/// Zone search by city, country, abbreviation or offset (spec §4.1, decision H).
/// Foundation has no zone → country map, so common cities are curated here; every other
/// IANA zone is still found by its id or city part.
public enum ZoneCatalog {
    public static let suggestions: [ZoneCatalogEntry] = [
        ZoneCatalogEntry("London", "United Kingdom", "Europe/London"),
        ZoneCatalogEntry("New York", "United States", "America/New_York"),
        ZoneCatalogEntry("San Francisco", "United States", "America/Los_Angeles"),
        ZoneCatalogEntry("Singapore", "Singapore", "Asia/Singapore"),
        ZoneCatalogEntry("UTC", "Coordinated Universal Time", "UTC"),
    ]

    /// Results ranked: city prefix, city contains, country, abbreviation, offset, id;
    /// then zones outside the catalog. Abbreviations and offsets are as of `instant`.
    public static func search(_ query: String, at instant: Date, limit: Int = 50) -> [ZoneSearchResult] {
        let query = normalize(query)
        guard !query.isEmpty else { return [] }
        let offset = parseOffset(query)
        var ranked: [(score: Int, order: Int, result: ZoneSearchResult)] = []

        for (order, entry) in entries.enumerated() {
            let zone = entry.zone, state = ZoneClock.state(zone, at: instant)
            let city = normalize(entry.city), country = normalize(entry.country)
            let score: Int? =
                if city.hasPrefix(query) { 0 }
                else if city.contains(query) { 1 }
                else if country.contains(query) { 2 }
                else if state.abbreviation.map(normalize) == query { 3 }
                else if offset == state.offsetSeconds { 4 }
                else if normalize(entry.zoneID).contains(query) { 5 }
                else { nil }
            if let score {
                ranked.append((score, order, ZoneSearchResult(name: entry.city, detail: "\(entry.country) · \(state.label)",
                                                              zone: zone)))
            }
        }

        for (order, id) in fallbackIDs.enumerated() {
            guard let zone = Zone(id) else { continue }
            let state = ZoneClock.state(zone, at: instant)
            let city = normalize(zone.cityName)
            let score: Int? =
                if city.hasPrefix(query) { 6 }
                else if normalize(id).contains(query) { 7 }
                else if offset == state.offsetSeconds { 8 }
                else { nil }
            if let score {
                ranked.append((score, entries.count + order,
                               ZoneSearchResult(name: zone.cityName, detail: "\(id) · \(state.label)", zone: zone)))
            }
        }

        return ranked.sorted { ($0.score, $0.order) < ($1.score, $1.order) }.prefix(limit).map(\.result)
    }

    // MARK: Private

    private static let catalogIDs = Set(entries.map(\.zoneID))

    private static let fallbackIDs = TimeZone.knownTimeZoneIdentifiers.sorted().filter { !catalogIDs.contains($0) }

    /// Case-, accent- and underscore-insensitive.
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// `+5:30`, `UTC+5:30`, `-7`, `utc−7` → seconds east of UTC.
    private static func parseOffset(_ query: String) -> Int? {
        guard let match = query.wholeMatch(of: /(?:utc|gmt)?\s*([+\-−])\s*(\d{1,2})(?::?(\d{2}))?/),
              let hours = Int(match.output.2), hours <= 14
        else { return nil }
        let minutes = match.output.3.flatMap { Int($0) } ?? 0
        let sign = match.output.1 == "+" ? 1 : -1
        return sign * (hours * 3600 + minutes * 60)
    }
}

extension ZoneCatalog {
    /// Suggestions first, then ~145 cities. Several cities can share a zone.
    public static let entries: [ZoneCatalogEntry] = suggestions + cities
}

private let cities: [ZoneCatalogEntry] = [
    // Europe
    ZoneCatalogEntry("Manchester", "United Kingdom", "Europe/London"),
    ZoneCatalogEntry("Edinburgh", "United Kingdom", "Europe/London"),
    ZoneCatalogEntry("Dublin", "Ireland", "Europe/Dublin"),
    ZoneCatalogEntry("Lisbon", "Portugal", "Europe/Lisbon"),
    ZoneCatalogEntry("Madrid", "Spain", "Europe/Madrid"),
    ZoneCatalogEntry("Barcelona", "Spain", "Europe/Madrid"),
    ZoneCatalogEntry("Paris", "France", "Europe/Paris"),
    ZoneCatalogEntry("Brussels", "Belgium", "Europe/Brussels"),
    ZoneCatalogEntry("Amsterdam", "Netherlands", "Europe/Amsterdam"),
    ZoneCatalogEntry("Berlin", "Germany", "Europe/Berlin"),
    ZoneCatalogEntry("Munich", "Germany", "Europe/Berlin"),
    ZoneCatalogEntry("Frankfurt", "Germany", "Europe/Berlin"),
    ZoneCatalogEntry("Hamburg", "Germany", "Europe/Berlin"),
    ZoneCatalogEntry("Zurich", "Switzerland", "Europe/Zurich"),
    ZoneCatalogEntry("Geneva", "Switzerland", "Europe/Zurich"),
    ZoneCatalogEntry("Vienna", "Austria", "Europe/Vienna"),
    ZoneCatalogEntry("Rome", "Italy", "Europe/Rome"),
    ZoneCatalogEntry("Milan", "Italy", "Europe/Rome"),
    ZoneCatalogEntry("Copenhagen", "Denmark", "Europe/Copenhagen"),
    ZoneCatalogEntry("Stockholm", "Sweden", "Europe/Stockholm"),
    ZoneCatalogEntry("Oslo", "Norway", "Europe/Oslo"),
    ZoneCatalogEntry("Helsinki", "Finland", "Europe/Helsinki"),
    ZoneCatalogEntry("Reykjavik", "Iceland", "Atlantic/Reykjavik"),
    ZoneCatalogEntry("Warsaw", "Poland", "Europe/Warsaw"),
    ZoneCatalogEntry("Prague", "Czechia", "Europe/Prague"),
    ZoneCatalogEntry("Budapest", "Hungary", "Europe/Budapest"),
    ZoneCatalogEntry("Athens", "Greece", "Europe/Athens"),
    ZoneCatalogEntry("Bucharest", "Romania", "Europe/Bucharest"),
    ZoneCatalogEntry("Sofia", "Bulgaria", "Europe/Sofia"),
    ZoneCatalogEntry("Belgrade", "Serbia", "Europe/Belgrade"),
    ZoneCatalogEntry("Zagreb", "Croatia", "Europe/Zagreb"),
    ZoneCatalogEntry("Istanbul", "Türkiye", "Europe/Istanbul"),
    ZoneCatalogEntry("Kyiv", "Ukraine", "Europe/Kyiv"),
    ZoneCatalogEntry("Moscow", "Russia", "Europe/Moscow"),
    ZoneCatalogEntry("Tallinn", "Estonia", "Europe/Tallinn"),
    ZoneCatalogEntry("Riga", "Latvia", "Europe/Riga"),
    ZoneCatalogEntry("Vilnius", "Lithuania", "Europe/Vilnius"),
    // Americas
    ZoneCatalogEntry("Boston", "United States", "America/New_York"),
    ZoneCatalogEntry("Washington", "United States", "America/New_York"),
    ZoneCatalogEntry("Miami", "United States", "America/New_York"),
    ZoneCatalogEntry("Atlanta", "United States", "America/New_York"),
    ZoneCatalogEntry("Toronto", "Canada", "America/Toronto"),
    ZoneCatalogEntry("Montreal", "Canada", "America/Toronto"),
    ZoneCatalogEntry("Halifax", "Canada", "America/Halifax"),
    ZoneCatalogEntry("St. John's", "Canada", "America/St_Johns"),
    ZoneCatalogEntry("Chicago", "United States", "America/Chicago"),
    ZoneCatalogEntry("Dallas", "United States", "America/Chicago"),
    ZoneCatalogEntry("Houston", "United States", "America/Chicago"),
    ZoneCatalogEntry("Austin", "United States", "America/Chicago"),
    ZoneCatalogEntry("Minneapolis", "United States", "America/Chicago"),
    ZoneCatalogEntry("Mexico City", "Mexico", "America/Mexico_City"),
    ZoneCatalogEntry("Denver", "United States", "America/Denver"),
    ZoneCatalogEntry("Salt Lake City", "United States", "America/Denver"),
    ZoneCatalogEntry("Calgary", "Canada", "America/Edmonton"),
    ZoneCatalogEntry("Phoenix", "United States", "America/Phoenix"),
    ZoneCatalogEntry("Los Angeles", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("Seattle", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("San Diego", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("San Jose", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("Portland", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("Las Vegas", "United States", "America/Los_Angeles"),
    ZoneCatalogEntry("Vancouver", "Canada", "America/Vancouver"),
    ZoneCatalogEntry("Anchorage", "United States", "America/Anchorage"),
    ZoneCatalogEntry("Honolulu", "United States", "Pacific/Honolulu"),
    ZoneCatalogEntry("Panama City", "Panama", "America/Panama"),
    ZoneCatalogEntry("Bogotá", "Colombia", "America/Bogota"),
    ZoneCatalogEntry("Lima", "Peru", "America/Lima"),
    ZoneCatalogEntry("Caracas", "Venezuela", "America/Caracas"),
    ZoneCatalogEntry("Santiago", "Chile", "America/Santiago"),
    ZoneCatalogEntry("Buenos Aires", "Argentina", "America/Argentina/Buenos_Aires"),
    ZoneCatalogEntry("Montevideo", "Uruguay", "America/Montevideo"),
    ZoneCatalogEntry("São Paulo", "Brazil", "America/Sao_Paulo"),
    ZoneCatalogEntry("Rio de Janeiro", "Brazil", "America/Sao_Paulo"),
    // Africa
    ZoneCatalogEntry("Casablanca", "Morocco", "Africa/Casablanca"),
    ZoneCatalogEntry("Algiers", "Algeria", "Africa/Algiers"),
    ZoneCatalogEntry("Tunis", "Tunisia", "Africa/Tunis"),
    ZoneCatalogEntry("Cairo", "Egypt", "Africa/Cairo"),
    ZoneCatalogEntry("Accra", "Ghana", "Africa/Accra"),
    ZoneCatalogEntry("Lagos", "Nigeria", "Africa/Lagos"),
    ZoneCatalogEntry("Addis Ababa", "Ethiopia", "Africa/Addis_Ababa"),
    ZoneCatalogEntry("Nairobi", "Kenya", "Africa/Nairobi"),
    ZoneCatalogEntry("Kampala", "Uganda", "Africa/Kampala"),
    ZoneCatalogEntry("Kigali", "Rwanda", "Africa/Kigali"),
    ZoneCatalogEntry("Dar es Salaam", "Tanzania", "Africa/Dar_es_Salaam"),
    ZoneCatalogEntry("Johannesburg", "South Africa", "Africa/Johannesburg"),
    ZoneCatalogEntry("Cape Town", "South Africa", "Africa/Johannesburg"),
    // Middle East and Asia
    ZoneCatalogEntry("Tel Aviv", "Israel", "Asia/Jerusalem"),
    ZoneCatalogEntry("Jerusalem", "Israel", "Asia/Jerusalem"),
    ZoneCatalogEntry("Riyadh", "Saudi Arabia", "Asia/Riyadh"),
    ZoneCatalogEntry("Doha", "Qatar", "Asia/Qatar"),
    ZoneCatalogEntry("Dubai", "United Arab Emirates", "Asia/Dubai"),
    ZoneCatalogEntry("Abu Dhabi", "United Arab Emirates", "Asia/Dubai"),
    ZoneCatalogEntry("Tehran", "Iran", "Asia/Tehran"),
    ZoneCatalogEntry("Baku", "Azerbaijan", "Asia/Baku"),
    ZoneCatalogEntry("Tbilisi", "Georgia", "Asia/Tbilisi"),
    ZoneCatalogEntry("Yerevan", "Armenia", "Asia/Yerevan"),
    ZoneCatalogEntry("Kabul", "Afghanistan", "Asia/Kabul"),
    ZoneCatalogEntry("Tashkent", "Uzbekistan", "Asia/Tashkent"),
    ZoneCatalogEntry("Almaty", "Kazakhstan", "Asia/Almaty"),
    ZoneCatalogEntry("Karachi", "Pakistan", "Asia/Karachi"),
    ZoneCatalogEntry("Lahore", "Pakistan", "Asia/Karachi"),
    ZoneCatalogEntry("Mumbai", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Delhi", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Bengaluru", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Hyderabad", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Chennai", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Kolkata", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Pune", "India", "Asia/Kolkata"),
    ZoneCatalogEntry("Colombo", "Sri Lanka", "Asia/Colombo"),
    ZoneCatalogEntry("Kathmandu", "Nepal", "Asia/Kathmandu"),
    ZoneCatalogEntry("Dhaka", "Bangladesh", "Asia/Dhaka"),
    ZoneCatalogEntry("Yangon", "Myanmar", "Asia/Yangon"),
    ZoneCatalogEntry("Bangkok", "Thailand", "Asia/Bangkok"),
    ZoneCatalogEntry("Ho Chi Minh City", "Vietnam", "Asia/Ho_Chi_Minh"),
    ZoneCatalogEntry("Hanoi", "Vietnam", "Asia/Ho_Chi_Minh"),
    ZoneCatalogEntry("Jakarta", "Indonesia", "Asia/Jakarta"),
    ZoneCatalogEntry("Kuala Lumpur", "Malaysia", "Asia/Kuala_Lumpur"),
    ZoneCatalogEntry("Manila", "Philippines", "Asia/Manila"),
    ZoneCatalogEntry("Hong Kong", "Hong Kong", "Asia/Hong_Kong"),
    ZoneCatalogEntry("Shanghai", "China", "Asia/Shanghai"),
    ZoneCatalogEntry("Beijing", "China", "Asia/Shanghai"),
    ZoneCatalogEntry("Shenzhen", "China", "Asia/Shanghai"),
    ZoneCatalogEntry("Taipei", "Taiwan", "Asia/Taipei"),
    ZoneCatalogEntry("Seoul", "South Korea", "Asia/Seoul"),
    ZoneCatalogEntry("Tokyo", "Japan", "Asia/Tokyo"),
    ZoneCatalogEntry("Osaka", "Japan", "Asia/Tokyo"),
    // Oceania
    ZoneCatalogEntry("Perth", "Australia", "Australia/Perth"),
    ZoneCatalogEntry("Darwin", "Australia", "Australia/Darwin"),
    ZoneCatalogEntry("Adelaide", "Australia", "Australia/Adelaide"),
    ZoneCatalogEntry("Brisbane", "Australia", "Australia/Brisbane"),
    ZoneCatalogEntry("Sydney", "Australia", "Australia/Sydney"),
    ZoneCatalogEntry("Melbourne", "Australia", "Australia/Melbourne"),
    ZoneCatalogEntry("Hobart", "Australia", "Australia/Hobart"),
    ZoneCatalogEntry("Auckland", "New Zealand", "Pacific/Auckland"),
    ZoneCatalogEntry("Wellington", "New Zealand", "Pacific/Auckland"),
    ZoneCatalogEntry("Suva", "Fiji", "Pacific/Fiji"),
]

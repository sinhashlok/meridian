import Foundation

/// What the app hands the widgets (decision BR): saved zones, jobs and the UTC display
/// setting, as JSON in the App Group. Widgets compute every time from it with Core, so it
/// holds wall-clock settings and IANA ids only, never resolved times.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// A saved zone (spec §7 `Zone`), in Clocks/Planner order.
    public struct SavedZoneData: Codable, Equatable, Sendable {
        public var ianaID: String
        public var name: String
        public var isHome: Bool
        public var workStart: ClockTime
        public var workEnd: ClockTime
        /// ISO weekdays (Monday = 1 … Sunday = 7).
        public var workDays: [Int]

        public init(ianaID: String, name: String, isHome: Bool, workStart: ClockTime = ClockTime(9, 0),
                    workEnd: ClockTime = ClockTime(18, 0), workDays: [Int] = [1, 2, 3, 4, 5]) {
            self.ianaID = ianaID
            self.name = name
            self.isHome = isHome
            self.workStart = workStart
            self.workEnd = workEnd
            self.workDays = workDays
        }
    }

    public var zones: [SavedZoneData]
    public var jobs: [Job]
    public var isUTCMode: Bool

    public init(zones: [SavedZoneData] = [], jobs: [Job] = [], isUTCMode: Bool = false) {
        self.zones = zones
        self.jobs = jobs
        self.isUTCMode = isUTCMode
    }

    public static let empty = WidgetSnapshot()

    // Missing keys take defaults, so an older app's file still reads after an update.
    private enum CodingKeys: String, CodingKey { case zones, jobs, isUTCMode }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zones = try container.decodeIfPresent([SavedZoneData].self, forKey: .zones) ?? []
        jobs = try container.decodeIfPresent([Job].self, forKey: .jobs) ?? []
        isUTCMode = try container.decodeIfPresent(Bool.self, forKey: .isUTCMode) ?? false
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }

    /// Never throws: a missing or unreadable file reads as `empty`, so a widget always draws.
    public static func decoded(from data: Data?) -> WidgetSnapshot {
        guard let data, let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return .empty }
        return snapshot
    }

    /// The home zone, or the first zone if none is marked home.
    public var home: SavedZoneData? { zones.first(where: \.isHome) ?? zones.first }

    /// Zones the Planner can draw (valid id, work hours start before they end), home first.
    public var plannerZones: [PlannerZone] {
        let homeFirst = zones.filter(\.isHome) + zones.filter { !$0.isHome }
        return homeFirst.compactMap { saved in
            guard let zone = Zone(saved.ianaID), saved.workStart < saved.workEnd else { return nil }
            return PlannerZone(zone: zone, name: saved.name, workStart: saved.workStart, workEnd: saved.workEnd,
                               workDays: Set(saved.workDays))
        }
    }
}

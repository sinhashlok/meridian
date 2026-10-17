import Foundation
import MeridianCore
import SwiftData
import SwiftUI  // Array.move(fromOffsets:toOffset:), used by List reordering

/// Work hours and days a new zone starts with (Settings › Work, decision BZ).
struct ZoneDefaults {
    var workStart = ClockTime(9, 0)
    var workEnd = ClockTime(18, 0)
    var workDays = [1, 2, 3, 4, 5]
}

/// Changes to saved zones that keep two rules true: exactly one home zone while any
/// zones exist, and `order` values that match the list order.
enum ZoneStore {
    /// First launch (spec §2): the device's zone becomes home.
    static func seed(into context: ModelContext, defaults: ZoneDefaults) {
        let device = Zone.device
        context.insert(SavedZone(ianaID: device.id, name: ZoneCatalog.displayName(for: device), isHome: true, order: 0,
                                 defaults: defaults))
    }

    static func contains(_ zone: Zone, named name: String, in zones: [SavedZone]) -> Bool {
        zones.contains { $0.ianaID == zone.id && $0.name == name }
    }

    static func add(_ zone: Zone, named name: String, to zones: [SavedZone], in context: ModelContext,
                    defaults: ZoneDefaults) {
        guard !contains(zone, named: name, in: zones) else { return }
        let order = (zones.map(\.order).max() ?? -1) + 1
        context.insert(SavedZone(ianaID: zone.id, name: name, isHome: zones.isEmpty, order: order, defaults: defaults))
    }

    static func makeHome(_ saved: SavedZone, among zones: [SavedZone]) {
        for zone in zones { zone.isHome = zone === saved }
    }

    static func delete(_ saved: SavedZone, from zones: [SavedZone], in context: ModelContext) {
        let wasHome = saved.isHome
        context.delete(saved)
        let remaining = zones.filter { $0 !== saved }.sorted { $0.order < $1.order }
        if wasHome, let first = remaining.first { first.isHome = true }
        renumber(remaining)
    }

    /// `List.onMove`: `zones` must be in display order.
    static func move(_ zones: [SavedZone], from source: IndexSet, to destination: Int) {
        var reordered = zones
        reordered.move(fromOffsets: source, toOffset: destination)
        renumber(reordered)
    }

    private static func renumber(_ zones: [SavedZone]) {
        for (index, zone) in zones.enumerated() where zone.order != index { zone.order = index }
    }
}

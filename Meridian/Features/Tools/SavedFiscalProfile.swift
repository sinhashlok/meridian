import Foundation
import MeridianCore
import SwiftData

/// A saved fiscal calendar (spec §4.6, decision Y): the Core `FiscalProfile` stored as
/// JSON, so its nested choices (basis, pattern, week-1 rule) survive as one value.
@Model
final class SavedFiscalProfile {
    var data: Data
    var isActive: Bool
    var order: Int

    init(profile: FiscalProfile, isActive: Bool, order: Int) {
        self.data = (try? JSONEncoder().encode(profile)) ?? Data()
        self.isActive = isActive
        self.order = order
    }

    /// `nil` only if the stored JSON no longer decodes.
    var profile: FiscalProfile? { try? JSONDecoder().decode(FiscalProfile.self, from: data) }
}

/// Reads and writes saved fiscal profiles through Core's `FiscalProfileList`, which owns
/// the rules (at most 3, exactly one active; decision AG). Like `ZoneStore` for zones.
enum FiscalStore {
    /// `saved` must be sorted by `order`.
    static func list(from saved: [SavedFiscalProfile]) -> FiscalProfileList {
        let pairs = saved.compactMap { row in row.profile.map { (row, $0) } }
        return FiscalProfileList(profiles: pairs.map(\.1), activeIndex: pairs.firstIndex { $0.0.isActive })
    }

    /// Makes the stored rows match `list`, reusing rows in order.
    static func save(_ list: FiscalProfileList, over saved: [SavedFiscalProfile], in context: ModelContext) {
        for (index, profile) in list.profiles.enumerated() {
            let isActive = index == list.activeIndex
            if index < saved.count {
                let row = saved[index]
                row.data = (try? JSONEncoder().encode(profile)) ?? row.data
                row.isActive = isActive
                row.order = index
            } else {
                context.insert(SavedFiscalProfile(profile: profile, isActive: isActive, order: index))
            }
        }
        for row in saved.dropFirst(list.profiles.count) { context.delete(row) }
    }

    /// Applies `change` to the stored list and saves it.
    static func update(_ saved: [SavedFiscalProfile], in context: ModelContext, _ change: (inout FiscalProfileList) -> Void) {
        var list = list(from: saved)
        change(&list)
        save(list, over: saved, in: context)
    }

    /// Debug `-MeridianFiscal india|retail|none`: replace the stored profiles.
    static func applyDebugLaunch(_ saved: [SavedFiscalProfile], in context: ModelContext) {
        guard let choice = DebugLaunch.fiscal else { return }
        var list = FiscalProfileList()
        switch choice {
        case "india": list.add(FiscalProfile.presets[0])
        case "retail": list.add(FiscalProfile.presets[2]); list.add(FiscalProfile.presets[0])
        default: break
        }
        save(list, over: saved, in: context)
    }
}

import Foundation
import SwiftData

/// The one SwiftData store. The app's scene and the Live Activity intents (which iOS runs
/// in the app's process, possibly with no window) share this container, so they never
/// write through two different stacks.
enum AppModel {
    static let types: [any PersistentModel.Type] = [SavedZone.self, SavedFiscalProfile.self, SavedTimer.self,
                                                    SessionRecord.self, SavedAlarm.self]

    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Schema(types))
        } catch {
            fatalError("Could not open the Meridian store: \(error)")
        }
    }()

    /// Empty, in memory: for #Preview.
    static var preview: ModelContainer {
        do {
            return try ModelContainer(for: Schema(types), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Could not make a preview store: \(error)")
        }
    }
}

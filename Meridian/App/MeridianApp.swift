import SwiftData
import SwiftUI

@main struct MeridianApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [SavedZone.self, SavedFiscalProfile.self])
    }
}

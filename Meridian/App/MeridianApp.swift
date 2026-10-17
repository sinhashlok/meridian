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
        .modelContainer(AppModel.container)
        // Refills alarms and job reminders while the app isn't open (M7 step 9).
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}

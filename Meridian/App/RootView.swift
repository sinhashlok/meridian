import SwiftData
import SwiftUI

/// The 5-tab shell from spec §2. First launch opens Zones.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.tab) {
            Tab("Zones", systemImage: "globe", value: "zones") { ZonesTab() }
            Tab("Alarms", systemImage: "alarm", value: "alarms") { AlarmsTab() }
            Tab("Timer", systemImage: "timer", value: "timer") { TimerTab() }
            Tab("Sessions", systemImage: "scope", value: "sessions") { SessionsTab() }
            Tab("Tools", systemImage: "wrench.and.screwdriver", value: "tools") { ToolsTab() }
        }
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsSheet()
        }
        // The Live Activities link here (meridian://timer, meridian://sessions).
        .onOpenURL { url in
            if url.scheme == "meridian", let host = url.host(), ["timer", "sessions"].contains(host) {
                appState.tab = host
            }
        }
        // Timers: re-check alarms on launch and on every return to the app (decision AR).
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { TimerAlarms.shared.sync(in: context) }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(AppModel.preview)
        .tint(.accent)
        .preferredColorScheme(.dark)
}

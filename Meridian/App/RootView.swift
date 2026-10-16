import SwiftData
import SwiftUI

/// The 5-tab shell from spec §2. First launch opens Zones.
struct RootView: View {
    @Environment(AppState.self) private var appState
    /// First launch opens Zones (spec §2); debug builds can pick another with `-MeridianTab`.
    @State private var tab = DebugLaunch.tab ?? "zones"

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $tab) {
            Tab("Zones", systemImage: "globe", value: "zones") { ZonesTab() }
            Tab("Alarms", systemImage: "alarm", value: "alarms") { AlarmsTab() }
            Tab("Timer", systemImage: "timer", value: "timer") { TimerTab() }
            Tab("Sessions", systemImage: "scope", value: "sessions") { SessionsTab() }
            Tab("Tools", systemImage: "wrench.and.screwdriver", value: "tools") { ToolsTab() }
        }
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsSheet()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .modelContainer(for: [SavedZone.self, SavedFiscalProfile.self], inMemory: true)
        .tint(.accent)
        .preferredColorScheme(.dark)
}

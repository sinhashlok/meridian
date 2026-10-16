import SwiftUI

/// The 5-tab shell from spec §2. First launch opens Zones.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView {
            Tab("Zones", systemImage: "globe") { ZonesTab() }
            Tab("Alarms", systemImage: "alarm") { AlarmsTab() }
            Tab("Timer", systemImage: "timer") { TimerTab() }
            Tab("Sessions", systemImage: "scope") { SessionsTab() }
            Tab("Tools", systemImage: "wrench.and.screwdriver") { ToolsTab() }
        }
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsSheet()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .tint(.accent)
        .preferredColorScheme(.dark)
}

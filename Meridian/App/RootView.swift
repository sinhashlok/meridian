import SwiftData
import SwiftUI

/// The 5-tab shell from spec §2. First launch opens Zones.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    // The same keys as ZonesTab and AlarmsTab, so a deep link can pick their segment.
    @AppStorage("zones.segment") private var zonesSegment: ZonesSegment = .planner
    @AppStorage("alarms.segment") private var alarmsSegment: AlarmsSegment = .alarms

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
        #if DEBUG
        .fullScreenCover(isPresented: .constant(DebugLaunch.screen == "liveActivity")) { LiveActivityPreview() }
        #endif
        .onOpenURL(perform: open)
        .task {
            guard let url = DebugLaunch.openURL else { return }
            try? await Task.sleep(for: .seconds(2))
            open(url)
        }
        // Keeps the widgets' snapshot current (decision BS). A separate view, so zone and job
        // changes don't redraw the whole tab shell.
        .background { WidgetSyncer() }
        // Re-check alarms on launch and on every return to the app (decision AR): AlarmKit's
        // update stream isn't trusted while suspended.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background { BackgroundRefresh.schedule() }
            guard phase == .active else { return }
            TimerAlarms.shared.sync(in: context)
            SessionAlarms.shared.sync()
            ClockAlarms.shared.sync(in: context)
            JobReminders.shared.sync(in: context)
        }
    }

    /// Live Activities link to meridian://timer and meridian://sessions; widgets to
    /// meridian://planner, meridian://clocks and meridian://jobs (decision CD).
    private func open(_ url: URL) {
        guard url.scheme == "meridian", let host = url.host() else { return }
        switch host {
        case "timer", "sessions":
            appState.tab = host
        case "planner", "clocks":
            zonesSegment = host == "planner" ? .planner : .clocks
            appState.tab = "zones"
        case "jobs":
            alarmsSegment = .jobs
            appState.tab = "alarms"
        default:
            break
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

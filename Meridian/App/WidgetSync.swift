import Foundation
import MeridianCore
import SwiftData
import SwiftUI
import WidgetKit

/// Writes the `WidgetSnapshot` (saved zones, jobs, UTC mode) to the App Group and asks
/// WidgetKit to redraw (decisions BR, BS). An unchanged snapshot isn't rewritten, so widgets
/// aren't reloaded for nothing (iOS limits how often they may be).
@MainActor enum WidgetSync {
    /// What the file holds now; read from disk on the first call. Compared as values, not
    /// bytes: JSONEncoder doesn't keep key order, so equal snapshots can encode differently.
    private static var written: WidgetSnapshot?

    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = SharedDefaults.snapshotURL else { return }  // no App Group entitlement
        if written == nil, let data = try? Data(contentsOf: url) { written = WidgetSnapshot.decoded(from: data) }
        guard snapshot != written else { return }
        do {
            try snapshot.encoded().write(to: url, options: .atomic)
            written = snapshot
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Widget snapshot not written: \(error)")
        }
    }
}

/// An invisible view in `RootView` that keeps the snapshot current. `@Query` follows every
/// change to zones and jobs, saved or not yet autosaved (SwiftData doesn't reliably post
/// `didSave` for autosaves), so no edit is missed.
struct WidgetSyncer: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Query(sort: \SavedJob.order) private var jobs: [SavedJob]

    private var snapshot: WidgetSnapshot {
        WidgetSnapshot(zones: zones.map(\.snapshotData), jobs: JobStore.jobs(from: jobs).map(\.job),
                       isUTCMode: appState.isUTCMode)
    }

    var body: some View {
        Color.clear
            // Runs again on every change, cancelling the wait before it: a burst of edits
            // (typing a name) writes once, half a second after the last one.
            .task(id: snapshot) {
                try? await Task.sleep(for: .milliseconds(500))
                if !Task.isCancelled { WidgetSync.write(snapshot) }
            }
            // Don't lose the last edit if the app is suspended during that wait.
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { WidgetSync.write(snapshot) }
            }
    }
}

private extension SavedZone {
    var snapshotData: WidgetSnapshot.SavedZoneData {
        WidgetSnapshot.SavedZoneData(ianaID: ianaID, name: name, isHome: isHome, workStart: workStart,
                                     workEnd: workEnd, workDays: workDays)
    }
}

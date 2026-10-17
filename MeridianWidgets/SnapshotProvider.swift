import MeridianCore
import SwiftUI
import WidgetKit

/// One timeline entry: a minute, and the snapshot the app last wrote (decision BR).
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// The timeline of every Meridian widget (decision BS): an entry now and one each minute
/// for 2 hours, then iOS asks again. The app also reloads widgets whenever its snapshot
/// changes (`WidgetSync`). Each widget works out its times from the entry with Core.
/// A `TimelineProvider` is like a generator the system calls for "what to show, and when".
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: DemoData.now, snapshot: DemoData.snapshot)
    }

    /// The widget picker shows the boards' data until the app has written its own.
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if let saved = SharedDefaults.readSnapshot() {
            completion(SnapshotEntry(date: .now, snapshot: saved))
        } else {
            completion(context.isPreview ? placeholder(in: context) : SnapshotEntry(date: .now, snapshot: .empty))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = SharedDefaults.readSnapshot() ?? .empty
        let entries = WidgetText.timelineDates(from: .now).map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// Where a widget tap opens the app (decision CD; handled in `RootView.open`).
enum WidgetLink {
    static let planner = URL(string: "meridian://planner")!
    static let clocks = URL(string: "meridian://clocks")!
    static let jobs = URL(string: "meridian://jobs")!
}

extension View {
    /// The app's background on the Home Screen; iOS swaps it out when tinted or clear.
    func homeScreenBackground() -> some View {
        containerBackground(Color.bgBase, for: .widget)
    }

    /// Lock Screen accessories draw on the wallpaper; circular ones get the system disc.
    func accessoryBackground(circular: Bool) -> some View {
        containerBackground(for: .widget) {
            if circular { AccessoryWidgetBackground() }
        }
    }
}

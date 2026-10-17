import MeridianCore
import SwiftData
import SwiftUI

/// Alarms › Alarms (spec §4.2, board AlarmsList, decision BN): the next ring and the New
/// alarm button, then every alarm, next ring first and off alarms last. Tap a row to edit.
struct AlarmsView: View {
    @Query(sort: \SavedAlarm.order) private var saved: [SavedAlarm]
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `Motion.stateChange`, or none under Reduce Motion (rows and fields move).
    private var stateChange: Animation? { Motion.moving(Motion.stateChange, reduceMotion: reduceMotion) }

    @State private var editing: EditTarget?
    @State private var showsChanges = false

    /// The edit sheet is for a new alarm or one saved row.
    enum EditTarget: Identifiable {
        case new
        case existing(SavedAlarm)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let row): "\(row.persistentModelID.hashValue)"
            }
        }
    }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let now = appState.now(timeline.date)
            let device = Zone.device
            let display: Zone = appState.isUTCMode ? .utc : device
            let pairs = AlarmStore.alarms(from: saved)
            let sorted = AlarmText.sorted(pairs.map(\.alarm), now: now, device: device)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ActionHeader(buttonTitle: "New alarm", action: { editing = .new }) {
                        summary(AlarmText.header(sorted, now: now, display: display, device: device))
                    }
                    if ClockAlarms.shared.alarmsDenied {
                        InlineBanner(title: "Alarms are off for Meridian",
                                     detail: "Your alarms won't ring until Alarms are allowed in Settings.",
                                     systemImage: "bell.slash",
                                     action: ("Open Settings", { openURL(URL(string: UIApplication.openSettingsURLString)!) }))
                    }
                    if sorted.isEmpty {
                        PlaceholderBox(text: "No alarms. Add one on this phone's clock, or one that keeps another "
                                       + "zone's time.")
                    } else {
                        ToolCard {
                            ForEach(sorted) { alarm in
                                if let row = pairs.first(where: { $0.alarm.id == alarm.id })?.row {
                                    AlarmRow(text: AlarmText.row(alarm, now: now, device: device), isOn: alarm.isOn,
                                             onToggle: { isOn in toggle(row, isOn) },
                                             onEdit: { editing = .existing(row) },
                                             onBadge: { showsChanges = true })
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
                .movingAnimation(Motion.layout, value: sorted.map(\.id))
            }
        }
        .sheet(item: $editing) { target in
            switch target {
            case .new:
                AlarmEditSheet(original: nil, onSave: { alarm in
                    AlarmStore.add(alarm, to: saved, in: context)
                    ClockAlarms.shared.sync(in: context)
                }, onDelete: nil)
            case .existing(let row):
                AlarmEditSheet(original: row.alarm, onSave: { alarm in
                    AlarmStore.update(row) { $0 = alarm }
                    ClockAlarms.shared.sync(in: context)
                }, onDelete: {
                    AlarmStore.delete(row, in: context)
                    ClockAlarms.shared.sync(in: context)
                })
            }
        }
        .sheet(isPresented: $showsChanges) {
            UpcomingChangesSheet(zones: zones, alsoUsed: alarmZones)
        }
        .onAppear {
            AlarmStore.applyDebugLaunch(saved, in: context)
            if DebugLaunch.alarms != nil { ClockAlarms.shared.sync(in: context) }
        }
        .task {
            // Debug: open the edit sheet on the first alarm once the demo rows are in.
            guard DebugLaunch.screen == "alarmEdit" || DebugLaunch.screen == "newAlarm" else { return }
            try? await Task.sleep(for: .milliseconds(300))
            if DebugLaunch.screen == "newAlarm" {
                editing = .new
            } else if let first = AlarmText.sorted(AlarmStore.alarms(from: saved).map(\.alarm), now: appState.now(),
                                                   device: .device).first,
                      let row = saved.first(where: { $0.alarm?.id == first.id }) {
                editing = .existing(row)
            }
        }
    }

    /// `Next:` in secondary text, the time in primary mono (board AlarmsList).
    @ViewBuilder
    private func summary(_ header: String?) -> some View {
        if let header, header.hasPrefix("Next: ") {
            Text("Next: \(Text(header.dropFirst(6)).monospaced().foregroundStyle(.textPrimary))")
                .meridianFont(.sub)
                .foregroundStyle(.textSecondary)
        } else {
            Text(header ?? "").meridianFont(.sub).foregroundStyle(.textSecondary)
        }
    }

    /// Zones of zoned alarms, for Upcoming clock changes.
    private var alarmZones: [(zone: Zone, name: String)] {
        let zones = AlarmStore.alarms(from: saved).compactMap { $0.alarm.zoneID.flatMap(Zone.init) }
        return Array(Set(zones)).map { ($0, ZoneCatalog.displayName(for: $0)) }
    }

    private func toggle(_ row: SavedAlarm, _ isOn: Bool) {
        withAnimation(stateChange) {
            AlarmStore.update(row) { $0.isOn = isOn }
        }
        ClockAlarms.shared.sync(in: context)
    }
}

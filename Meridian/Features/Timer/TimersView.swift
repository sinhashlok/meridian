import MeridianCore
import SwiftData
import SwiftUI

/// Timer › Timers (spec §4.4, board TimerUntil): "2 running" and the New timer button,
/// then one card per timer, done first, then soonest first (decision AJ).
struct TimersView: View {
    @Query(sort: \SavedTimer.order) private var saved: [SavedTimer]
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// `Motion.stateChange`, or none under Reduce Motion (rows and fields move).
    private var stateChange: Animation? { Motion.moving(Motion.stateChange, reduceMotion: reduceMotion) }

    @State private var isAdding = false
    @State private var starts = 0

    var body: some View {
        // Ticks once a second; every value is recomputed from stored instants.
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = appState.now(timeline.date)
            let display: Zone = appState.isUTCMode ? .utc : .device
            let pairs = TimerStore.timers(from: saved)
            let sorted = TimerText.sorted(pairs.map(\.timer), now: now)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    ActionHeader(TimerText.header(pairs.map(\.timer), now: now), buttonTitle: "New timer") {
                        isAdding = true
                    }
                    if !pairs.isEmpty { permissionNote }
                    if sorted.isEmpty {
                        PlaceholderBox(text: "No timers. Start a countdown, or one that ends at a time in any zone.")
                    }
                    ForEach(sorted) { timer in
                        if let row = pairs.first(where: { $0.timer.id == timer.id })?.row {
                            TimerCard(timer: timer, now: now, display: display, displayIsPhone: !appState.isUTCMode) {
                                perform($0, on: row, now: now)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenMargin)
                .padding(.bottom, Spacing.sectionGap)
                .movingAnimation(Motion.layout, value: sorted.map(\.id))
            }
        }
        .sheet(isPresented: $isAdding) {
            NewTimerSheet { timer in
                TimerStore.add(timer, to: saved, in: context)
                starts += 1
                TimerAlarms.shared.sync(in: context)
            }
        }
        .sensoryFeedback(Haptic.timerStart, trigger: starts)
        .onAppear {
            TimerStore.applyDebugLaunch(saved, now: appState.now(), in: context)
            if DebugLaunch.timers != nil { TimerAlarms.shared.sync(in: context) }
            if DebugLaunch.screen == "newTimer" || DebugLaunch.screen == "newTimerUntil" { isAdding = true }
        }
    }

    /// Decision AI: say plainly when timers can't ring through Silent.
    @ViewBuilder
    private var permissionNote: some View {
        let alarms = TimerAlarms.shared
        if alarms.alarmsDenied {
            AlarmPermissionNote(subject: "timers", notificationsDenied: alarms.notificationsDenied)
        }
    }

    private func perform(_ action: TimerAction, on row: SavedTimer, now: Date) {
        withAnimation(stateChange) {
            switch action {
            case .pause: TimerStore.update(row) { $0.pause(at: now) }
            case .resume: TimerStore.update(row) { $0.resume(at: now) }
            case .addMinute: TimerStore.update(row) { $0.addMinute(at: now) }
            case .restart:
                TimerStore.update(row) { $0.restart(at: now) }
                starts += 1
            case .remove: TimerStore.delete(row, in: context)
            }
        }
        TimerAlarms.shared.sync(in: context)
    }
}

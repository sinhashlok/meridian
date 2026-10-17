#if DEBUG
import AlarmKit
import MeridianCore
import SwiftUI

/// DEBUG-only Settings rows for the two AlarmKit questions M0.5 left open (decision BP).
/// Run them on the iPhone, then copy the results into docs/notes/alarmkit.md.
struct AlarmKitProbeSection: View {
    @State private var limitResult: String?
    @State private var relativeResult: String?
    @State private var isBusy = false

    var body: some View {
        Section {
            Button("AlarmKit limit test") { Task { await limitTest() } }
                .disabled(isBusy)
            if let limitResult { Text(limitResult).meridianFont(.caption).foregroundStyle(.textSecondary) }
            Button("Relative alarm in 3 min") { Task { await relativeTest() } }
                .disabled(isBusy)
            if let relativeResult { Text(relativeResult).meridianFont(.caption).foregroundStyle(.textSecondary) }
        } header: {
            Text("Debug · AlarmKit")
        } footer: {
            Text("Limit test schedules far-future alarms until AlarmKit refuses one, then cancels them. "
                 + "Relative test: after scheduling, change Settings › General › Date & Time › Time Zone and note "
                 + "when it rings.")
        }
    }

    /// Schedules one-off alarms on 1 Jan 2030 until AlarmKit refuses, counts, then cancels them.
    private func limitTest() async {
        isBusy = true
        defer { isBusy = false }
        guard !(await AlarmService.alarmsDenied(askingIf: true)) else { limitResult = "Alarms permission denied."; return }
        let before = AlarmService.liveAlarmIDs.count
        let start = try! EpochParser.parseISO8601("2030-01-01T00:00:00Z").date
        var ids: [UUID] = []
        var failure = "no refusal up to 1,000"
        for index in 0..<1000 {
            let id = UUID()
            do {
                try await AlarmService.trySchedule(id: id, .fixed(start.addingTimeInterval(TimeInterval(index * 60))),
                                                   title: "Limit test")
                ids.append(id)
            } catch {
                failure = "refused: \(error)"
                break
            }
        }
        for id in ids { AlarmService.cancelAlarm(id: id) }
        limitResult = "\(ids.count) scheduled alongside \(before) already there, then \(failure). Cancelled them."
        print("AlarmKit limit test: \(limitResult!)")
    }

    /// A one-off relative alarm three minutes ahead on the phone's clock.
    private func relativeTest() async {
        isBusy = true
        defer { isBusy = false }
        let ring = ZoneClock.local(Date.now.addingTimeInterval(180), in: .device)
        let ok = await AlarmService.scheduleRelativeAlarm(id: UUID(), hour: ring.hour, minute: ring.minute, weekdays: [],
                                                          title: "Relative test", snoozeMinutes: nil)
        relativeResult = ok
            ? "Scheduled for \(ClockTime(ring.hour, ring.minute).text) on this phone's clock (\(Zone.device.id))."
            : "AlarmKit refused it."
    }
}
#endif

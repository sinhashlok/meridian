import AlarmKit
import SwiftUI

// M0.5 AlarmKit spike (branch spike/alarmkit). Throwaway: answers "does an AlarmKit
// alarm ring through lock, Silent and Focus?" before M7. See docs/notes/alarmkit.md.

/// AlarmKit requires a metadata type even when there is nothing to attach.
/// `nonisolated` keeps it off the MainActor so it can be `Sendable`, as AlarmKit requires.
nonisolated struct SpikeMetadata: AlarmMetadata {}

enum AlarmSpike {
    enum SpikeError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            "Alarms are off for Meridian. Turn them on in Settings › Apps › Meridian."
        }
    }

    /// Asks for permission if needed, then schedules a one-off alarm two minutes out.
    /// Returns the alarm id and the instant it should ring.
    static func scheduleInTwoMinutes() async throws -> (id: Alarm.ID, fireDate: Date) {
        let manager = AlarmManager.shared

        var state = manager.authorizationState
        if state == .notDetermined {
            state = try await manager.requestAuthorization()
        }
        guard state == .authorized else { throw SpikeError.notAuthorized }

        // An absolute instant, not a wall-clock time: this is the `.fixed` schedule the
        // "Keep <zone> time" plan in CLAUDE.md relies on.
        let fireDate = Date.now.addingTimeInterval(120)
        let id = Alarm.ID()

        let attributes = AlarmAttributes<SpikeMetadata>(
            presentation: AlarmPresentation(alert: alert()),
            tintColor: .accent
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
        return (id, fireDate)
    }

    static func cancel(_ id: Alarm.ID) throws {
        try AlarmManager.shared.cancel(id: id)
    }

    /// From iOS 26.1 the system draws the Stop button itself and `stopButton` is deprecated.
    /// iOS 26.0 still needs it.
    private static func alert() -> AlarmPresentation.Alert {
        if #available(iOS 26.1, *) {
            AlarmPresentation.Alert(title: "Meridian spike alarm")
        } else {
            AlarmPresentation.Alert(
                title: "Meridian spike alarm",
                stopButton: AlarmButton(text: "Stop", textColor: .accent, systemImageName: "stop.circle")
            )
        }
    }
}

/// One button to schedule, a live status line from AlarmKit, and Cancel.
struct AlarmSpikeView: View {
    @State private var alarmID: Alarm.ID?
    @State private var fireDate: Date?
    @State private var alarmState = "None scheduled"
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: Spacing.m) {
            Button {
                Task { await schedule() }
            } label: {
                Text("Schedule alarm in 2 min")
                    .meridianFont(.headline)
                    .foregroundStyle(.onAccent)
                    .frame(maxWidth: .infinity, minHeight: Spacing.minTapTarget)
            }
            .buttonStyle(.borderedProminent)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                LabeledContent("AlarmKit state", value: alarmState)
                if let fireDate {
                    LabeledContent("Rings at") { Text(fireDate, style: .time) }
                    LabeledContent("In") { Text(timerInterval: Date.now...fireDate, countsDown: true) }
                }
            }
            .meridianFont(.sub)
            .foregroundStyle(.textSecondary)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .meridianFont(.sub)
                    .foregroundStyle(.statusDanger)
            }

            if let alarmID {
                Button("Cancel alarm", role: .destructive) {
                    try? AlarmSpike.cancel(alarmID)
                }
                .frame(minHeight: Spacing.minTapTarget)
            }
        }
        .padding(.horizontal, Spacing.screenMargin)
        .task { await watchAlarms() }
    }

    private func schedule() async {
        errorMessage = nil
        do {
            let result = try await AlarmSpike.scheduleInTwoMinutes()
            alarmID = result.id
            fireDate = result.fireDate
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// AlarmKit pushes the full alarm list whenever anything changes. An alarm that
    /// drops out of the list is no longer scheduled (it was stopped or cancelled).
    private func watchAlarms() async {
        for await alarms in AlarmManager.shared.alarmUpdates {
            guard let alarmID else { continue }
            if let alarm = alarms.first(where: { $0.id == alarmID }) {
                alarmState = "\(alarm.state)"
            } else {
                alarmState = "Gone (stopped or cancelled)"
                self.alarmID = nil
                fireDate = nil
            }
        }
    }
}

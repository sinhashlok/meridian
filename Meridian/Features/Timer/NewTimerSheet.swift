import MeridianCore
import SwiftData
import SwiftUI

/// New timer sheet (spec §4.4, decision AN): Duration (h/m/s wheels) or Until (a wall
/// time in a zone, with First | Second when that time repeats). Remembers the last
/// length, time and zone.
struct NewTimerSheet: View {
    let onStart: (CountdownTimer) -> Void

    @AppStorage("timer.new.until") private var isUntil = DebugLaunch.screen == "newTimerUntil"
    @AppStorage("timer.new.seconds") private var lastSeconds = 600
    /// Until: minutes after midnight, and the zone (UTC by default; decision AN).
    @AppStorage("timer.until.minuteOfDay") private var minuteOfDay = 120
    @AppStorage("timer.until.zone") private var zoneID = Zone.utc.id

    @State private var name = ""
    @State private var hours = 0
    @State private var minutes = 10
    @State private var seconds = 0
    @State private var occurrence: Occurrence = .first

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Query(sort: \SavedZone.order) private var zones: [SavedZone]

    private var durationSeconds: Int { hours * 3600 + minutes * 60 + seconds }
    private var zone: Zone { Zone(zoneID) ?? .utc }
    private var untilTime: Binding<ClockTime> {
        Binding(get: { ClockTime(minuteOfDay / 60, minuteOfDay % 60) },
                set: { minuteOfDay = $0.hour * 60 + $0.minute })
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = appState.now(timeline.date)
                Form {
                    Section {
                        Picker("Kind", selection: $isUntil) {
                            Text("Duration").tag(false)
                            Text("Until").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    Section("Name") {
                        TextField(isUntil ? "Deploy window" : "Standup prep", text: $name)
                            .meridianFont(.body)
                    }

                    if isUntil {
                        untilSection(now: now)
                    } else {
                        durationSection
                    }
                }
                .scrollContentBackground(.hidden)
            }
            // Menus and Cancel are not "on" states: neutral, not orange (spec §3.2).
            .tint(.textPrimary)
            .navigationTitle("New timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // The screen's one filled orange button (spec §3.2).
                    Button("Start", action: start)
                        .buttonStyle(.borderedProminent)
                        .tint(.accent)
                        .foregroundStyle(.onAccent)
                        .disabled(!isUntil && durationSeconds == 0)
                }
            }
        }
        .presentationBackground(.bgElevated)
        .onAppear {
            hours = lastSeconds / 3600
            minutes = lastSeconds % 3600 / 60
            seconds = lastSeconds % 60
        }
    }

    // MARK: Duration

    private var durationSection: some View {
        Section("Length") {
            HStack(spacing: 0) {
                wheel("Hours", selection: $hours, range: 0...23, unit: "h")
                wheel("Minutes", selection: $minutes, range: 0...59, unit: "min")
                wheel("Seconds", selection: $seconds, range: 0...59, unit: "s")
            }
            .frame(minHeight: 180)
        }
    }

    private func wheel(_ title: String, selection: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array(range), id: \.self) { Text("\($0) \(unit)").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
    }

    // MARK: Until

    @ViewBuilder
    private func untilSection(now: Date) -> some View {
        let display: Zone = appState.isUTCMode ? .utc : .device
        let preview = TimerText.untilPreview(hour: minuteOfDay / 60, minute: minuteOfDay % 60, in: zone,
                                             occurrence: occurrence, now: now, display: display)
        Section {
            ClockTimePicker(title: "Ends at", time: untilTime)
            LabeledContent("Zone") {
                ToolZoneMenu(prefix: "", zoneID: $zoneID, zones: zones)
            }
            if preview.isRepeated {
                // Shown only when the chosen time happens twice (decision AM).
                LabeledContent("Occurrence") {
                    Picker("Occurrence", selection: $occurrence) {
                        Text("First").tag(Occurrence.first)
                        Text("Second").tag(Occurrence.second)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(preview.ends)
                    .meridianFont(.sub)
                    .foregroundStyle(.textPrimary)
                if let note = preview.note {
                    NoteLine(systemImage: "clock.arrow.circlepath", text: note)
                        .padding(.horizontal, -Spacing.xs)
                }
            }
            .padding(.top, Spacing.xs)
        }
    }

    // MARK: Start

    private func start() {
        let now = appState.now()
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let timer: CountdownTimer
        if isUntil {
            timer = .until(hour: minuteOfDay / 60, minute: minuteOfDay % 60, in: zone, occurrence: occurrence,
                           name: trimmed, now: now)
        } else {
            lastSeconds = durationSeconds
            timer = .duration(seconds: durationSeconds, name: trimmed, now: now)
        }
        onStart(timer)
        dismiss()
    }
}
